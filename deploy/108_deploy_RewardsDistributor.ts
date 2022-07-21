import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, getOrNull, log, get } = deployments
  const { deployer } = await getNamedAccounts()

  const distributor = await getOrNull("RewardsDistributor")
  if (distributor) {
    log(`reusing "RewardsDistributor" at ${distributor.address}`)
  } else {
    await deploy("RewardsDistributor", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("Core")).address,
        (await get("WBNB")).address
      ]
    })
  }
}

export default func
func.tags = ["RewardsDistributor"]
func.dependencies = ["Core","WBNB"]