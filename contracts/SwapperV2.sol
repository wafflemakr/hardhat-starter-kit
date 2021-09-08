//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IUniswapV2Exchange.sol";
import "./interfaces/IBalancerPool.sol";
import { Swapper as SwapperV1 } from "./Swapper.sol";

/**
    @title Multi Swap Tool a.k.a. Swapper
    @author wafflemakr
*/
contract SwapperV2 is SwapperV1 {
  using SafeMath for uint256;
  using UniswapV2ExchangeLib for IUniswapV2Exchange;

  // ======== STATE V2 ======== //

  enum Dex {
    UNISWAP,
    BALANCER
  }

  struct Swaps {
    address token;
    address pool;
    uint256 distribution;
    Dex dex;
  }

  // =========================== //

  /**
        @dev infite approve if allowance is not enough
   */
  function _setApproval(
    address to,
    address erc20,
    uint256 srcAmt
  ) internal {
    if (srcAmt > IERC20(erc20).allowance(address(this), to)) {
      IERC20(erc20).approve(to, type(uint256).max);
    }
  }

  /**
        @notice make a swap using uniswap
   */
  function _swapUniswap(
    address pool,
    IERC20 fromToken,
    IERC20 destToken,
    uint256 amount
  ) internal {
    require(fromToken != destToken, "SAME_TOKEN");
    require(amount > 0, "ZERO-AMOUNT");

    uint256 returnAmount = IUniswapV2Exchange(pool).getReturn(
      fromToken,
      destToken,
      amount
    );

    fromToken.transfer(pool, amount);
    if (
      uint256(uint160(address(fromToken))) <
      uint256(uint160(address(destToken)))
    ) {
      IUniswapV2Exchange(pool).swap(0, returnAmount, msg.sender, "");
    } else {
      IUniswapV2Exchange(pool).swap(returnAmount, 0, msg.sender, "");
    }
  }

  /**
        @notice make a swap using balancer
    */
  function _swapBalancer(
    address pool,
    address fromToken,
    address destToken,
    uint256 amount
  ) internal {
    _setApproval(pool, fromToken, amount);

    (uint256 tokenAmountOut, ) = IBalancerPool(pool).swapExactAmountIn(
      fromToken,
      amount,
      destToken,
      1,
      type(uint256).max
    );

    IERC20(destToken).transfer(msg.sender, tokenAmountOut);
  }

  /**
    @notice swap ETH for multiple tokens according to distribution % and a dex
    @dev tokens length should be equal to distribution length
    @dev msg.value will be completely converted to tokens
    @param swaps array of swap struct containing details about the swap to perform
   */
  function swapMultiple(Swaps[] memory swaps) external payable {
    require(msg.value > 0);
    require(swaps.length < 10);

    // Calculate ETH left after subtracting fee
    uint256 afterFee = msg.value.sub(msg.value.mul(fee).div(10000));

    // Wrap all ether that is going to be used in the swap
    WETH.deposit{ value: afterFee }();

    for (uint256 i = 0; i < swaps.length; i++) {
      if (swaps[i].dex == Dex.UNISWAP)
        _swapUniswap(
          swaps[i].pool,
          WETH,
          IERC20(swaps[i].token),
          afterFee.mul(swaps[i].distribution).div(10000)
        );
      else if (swaps[i].dex == Dex.BALANCER)
        _swapBalancer(
          swaps[i].pool,
          address(WETH),
          swaps[i].token,
          afterFee.mul(swaps[i].distribution).div(10000)
        );
      else revert("DEX NOT SUPPORTED");
    }

    // Send remaining ETH to fee recipient
    payable(feeRecipient).transfer(address(this).balance);
  }
}
