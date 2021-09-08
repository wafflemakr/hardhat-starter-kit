const axios = require("axios");
const chai = require("chai");
const {
  getNamedAccounts,
  deployments: { fixture, deploy },
} = require("hardhat");
const { solidity } = require("ethereum-waffle");
const { time } = require("@openzeppelin/test-helpers");
const { expect } = chai;
chai.use(solidity);

const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const LINK_ADDRESS = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
const USDT_ADDRESS = "0xdac17f958d2ee523a2206206994597c13d831ec7";

const BALANCER_REGISTRY = "0x65e67cbc342712DF67494ACEfc06fe951EE93982";
const UNI_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";

// HELPERS

// web3
// const toWei = (value) => web3.utils.toWei(String(value));
// const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

// ethers
const toWei = (num) => String(ethers.utils.parseEther(String(num)));
const fromWei = (num) => Number(ethers.utils.formatEther(num));

const printGas = async (tx) => {
  const receipt = await tx.wait();

  console.log("\tGas Used:", Number(receipt.gasUsed));
};

contract("Swapper", () => {
  before(async function () {
    ({ deployer, feeRecipient, user } = await getNamedAccounts());

    userSigner = await ethers.provider.getSigner(user);

    await fixture(["Swapper"]);

    swapper = await ethers.getContract("Swapper");

    dai = await ethers.getContractAt("IERC20", DAI_ADDRESS);
    link = await ethers.getContractAt("IERC20", LINK_ADDRESS);
    usdt = await ethers.getContractAt("IERC20", USDT_ADDRESS);

    balancer = await ethers.getContractAt(
      "IBalancerRegistry",
      BALANCER_REGISTRY
    );
    factory = await ethers.getContractAt("IUniswapV2Factory", UNI_FACTORY);
  });

  it("Should use swapper V1 tool", async function () {
    const distribution = [3000, 7000]; // 30% and 70%
    const tokens = [DAI_ADDRESS, LINK_ADDRESS];
    const intialFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    const tx = await swapper
      .connect(userSigner)
      .swap(tokens, distribution, { value: toWei(1) });

    await printGas(tx);

    const balanceDAI = await dai.balanceOf(user);
    const balanceLINK = await link.balanceOf(user);
    const contractBalance = await web3.eth.getBalance(swapper.address);
    const finalFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    expect(fromWei(balanceDAI)).to.be.greaterThan(0);
    expect(fromWei(balanceLINK)).to.be.greaterThan(0);
    expect(Number(contractBalance)).to.be.equal(0);
    expect(fromWei(finalFeeRecipientBalance)).to.be.greaterThan(
      fromWei(intialFeeRecipientBalance)
    );
  });

  it("Should upgrade to V2", async function () {
    await deploy("Swapper", {
      contract: "SwapperV2",
      from: deployer,
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
        viaAdminContract: "DefaultProxyAdmin",
      },
      log: true,
    });

    swapper = await ethers.getContract("Swapper");
  });

  it("Should swap 2 tokens using best dex", async function () {
    const TOKENS = [DAI_ADDRESS, LINK_ADDRESS];
    const AMOUNT = [0.3, 0.7];
    const DISTRIBUTIONS = [3000, 7000];

    const swaps = [];

    for (let i = 0; i < TOKENS.length; i++) {
      const token = TOKENS[i];
      const amount = AMOUNT[i];
      const distribution = DISTRIBUTIONS[i];

      const { data } = await axios.get(
        `https://api.1inch.exchange/v3.0/1/quote?fromTokenAddress=${WETH_ADDRESS}&toTokenAddress=${token}&amount=${toWei(
          amount
        )}&protocols=UNISWAP_V2,BALANCER`
      );
      console.log(`\tSwap WETH to ${token} in ${data.protocols[0][0][0].name}`);

      let swapData;

      if (data.protocols[0][0][0].name === "UNISWAP_V2") {
        const pool = await factory.getPair(WETH_ADDRESS, token);
        swapData = { token, pool, distribution, dex: 0 };
      } else {
        const pools = await balancer.getBestPoolsWithLimit(
          WETH_ADDRESS,
          token,
          1
        );
        swapData = { token, pool: pools[0], distribution, dex: 1 };
      }

      swaps.push(swapData);
    }

    const intialFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    const tx = await swapper.connect(userSigner).swapMultiple(swaps, {
      value: toWei(1),
    });

    await printGas(tx);

    const balanceDAI = await dai.balanceOf(user);
    const balanceLINK = await link.balanceOf(user);
    const contractBalance = await web3.eth.getBalance(swapper.address);
    const finalFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    expect(fromWei(balanceDAI)).to.be.greaterThan(0);
    expect(fromWei(balanceLINK)).to.be.greaterThan(0);
    expect(Number(contractBalance)).to.be.equal(0);
    expect(fromWei(finalFeeRecipientBalance)).to.be.greaterThan(
      fromWei(intialFeeRecipientBalance)
    );

    // assert.notEqual(balanceDAI, 0);
    // assert.notEqual(balanceLINK, 0);
    // assert.equal(contractBalance, 0);
    // assert(
    //   fromWei(finalFeeRecipientBalance) > fromWei(intialFeeRecipientBalance)
    // );
  });
});
