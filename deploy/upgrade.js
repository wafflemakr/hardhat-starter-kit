module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Swapper", {
    from: deployer,
    contract: "SwapperV2",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      viaAdminContract: "DefaultProxyAdmin",
    },

    log: true,
  });
};

module.exports.tags = ["SwapperV2"];
