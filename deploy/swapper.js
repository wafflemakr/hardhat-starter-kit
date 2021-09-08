const FEE = 100; // 0.1%

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer, feeRecipient } = await getNamedAccounts();

  await deploy("Swapper", {
    from: deployer,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      viaAdminContract: "DefaultProxyAdmin",
      execute: {
        init: {
          methodName: "initialize",
          args: [feeRecipient, FEE],
        },
      },
    },

    log: true,
  });
};

module.exports.tags = ["Swapper"];
