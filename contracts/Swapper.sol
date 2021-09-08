//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IUniswapV2Exchange.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IBalancerRegistry.sol";
import "./interfaces/IBalancerPool.sol";

/**
    @title Multi Swap Tool a.k.a. Swapper
    @author wafflemakr
*/
contract Swapper is Initializable {
  using SafeMath for uint256;
  using UniswapV2ExchangeLib for IUniswapV2Exchange;

  // ======== STATE V1 ======== //

  IUniswapV2Router internal constant router =
    IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  IUniswapV2Factory internal constant factory =
    IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

  IWETH internal constant WETH =
    IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  // Receives 0.1% of the total ETH used for swaps
  address public feeRecipient;

  // fee charged, initializes in 0.1%
  uint256 public fee;

  // =========================== //

  /**
    @notice intialize contract variables
   */
  function initialize(address _feeRecipient, uint256 _fee)
    external
    initializer
  {
    require(_feeRecipient != address(0));
    require(_fee > 0);
    feeRecipient = _feeRecipient;
    fee = _fee;
  }

  /**
    @notice get erc20 representative address for ETH
   */
  function getAddressETH() public pure returns (address eth) {
    eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  }

  /**
    @notice make a swap using uniswap
   */
  function _swapUniswap(
    IERC20 fromToken,
    IERC20 destToken,
    uint256 amount
  ) internal returns (uint256 returnAmount) {
    require(fromToken != destToken, "SAME_TOKEN");
    require(amount > 0, "ZERO-AMOUNT");

    IUniswapV2Exchange exchange = factory.getPair(fromToken, destToken);
    returnAmount = exchange.getReturn(fromToken, destToken, amount);

    fromToken.transfer(address(exchange), amount);
    if (
      uint256(uint160(address(fromToken))) <
      uint256(uint160(address(destToken)))
    ) {
      exchange.swap(0, returnAmount, msg.sender, "");
    } else {
      exchange.swap(returnAmount, 0, msg.sender, "");
    }
  }

  /**
    @notice swap ETH for multiple tokens according to distribution %
    @dev tokens length should be equal to distribution length
    @dev msg.value will be completely converted to tokens
    @param tokens array of tokens to swap to
    @param distribution array of % amount to convert eth from (3054 = 30.54%)
   */
  function swap(address[] memory tokens, uint256[] memory distribution)
    external
    payable
  {
    require(msg.value > 0);
    require(tokens.length == distribution.length);

    // Calculate ETH left after subtracting fee
    uint256 afterFee = msg.value.sub(msg.value.mul(fee).div(100000));

    // Wrap all ether that is going to be used in the swap
    WETH.deposit{ value: afterFee }();

    for (uint256 i = 0; i < tokens.length; i++) {
      _swapUniswap(
        WETH,
        IERC20(tokens[i]),
        afterFee.mul(distribution[i]).div(10000)
      );
    }

    // Send remaining ETH to fee recipient
    payable(feeRecipient).transfer(address(this).balance);
  }

  /**
    @notice swap ETH for multiple tokens according to distribution % using router and WETH
    @dev tokens length should be equal to distribution length
    @dev msg.value will be completely converted to tokens
    @param tokens array of tokens to swap to
    @param distribution array of % amount to convert eth from (3054 = 30.54%)
   */
  function swapWithRouter(
    address[] memory tokens,
    uint256[] memory distribution
  ) external payable {
    require(msg.value > 0);
    require(tokens.length == distribution.length);

    // Calculate ETH left after subtracting fee
    uint256 afterFee = msg.value.sub(msg.value.mul(fee).div(100000));

    // Wrap all ether that is going to be used in the swap
    WETH.deposit{ value: afterFee }();
    WETH.approve(address(router), afterFee);

    address[] memory path = new address[](2);
    path[0] = address(WETH);

    for (uint256 i = 0; i < tokens.length; i++) {
      path[1] = tokens[i];
      router.swapExactTokensForTokens(
        afterFee.mul(distribution[i]).div(10000),
        1,
        path,
        msg.sender,
        block.timestamp + 1
      );
    }

    // Send remaining ETH to fee recipient
    payable(feeRecipient).transfer(address(this).balance);
  }

  /**
    @notice swap ETH for multiple tokens according to distribution % using router and ETH
    @dev tokens length should be equal to distribution length
    @dev msg.value will be completely converted to tokens
    @param tokens array of tokens to swap to
    @param distribution array of % amount to convert eth from (3054 = 30.54%)
   */
  function swapWithRouterETH(
    address[] memory tokens,
    uint256[] memory distribution
  ) external payable {
    require(msg.value > 0);
    require(tokens.length == distribution.length);

    // Calculate ETH left after subtracting fee
    uint256 afterFee = msg.value.sub(msg.value.mul(fee).div(100000));

    address[] memory path = new address[](2);
    path[0] = address(WETH);

    for (uint256 i = 0; i < tokens.length; i++) {
      path[1] = tokens[i];

      uint256 amountETH = afterFee.mul(distribution[i]).div(10000);

      router.swapExactETHForTokens{ value: amountETH }(
        amountETH,
        path,
        msg.sender,
        block.timestamp + 1
      );
    }

    // Send remaining ETH to fee recipient
    payable(feeRecipient).transfer(address(this).balance);
  }
}
