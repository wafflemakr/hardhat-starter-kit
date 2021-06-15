const CONTRACT_NAME = "Greeter";

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy(CONTRACT_NAME, {
    from: deployer,
    args: ["First Greet"],
    log: true,
  });
};

module.exports.tags = [CONTRACT_NAME];
