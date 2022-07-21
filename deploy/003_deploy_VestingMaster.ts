import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, getOrNull, log, get } = deployments
  const { deployer } = await getNamedAccounts()

  const vestingMaster = await getOrNull("VestingMaster")
  if (vestingMaster) {
    log(`reusing "VestingMaster" at ${vestingMaster.address}`)
  } else {
    await deploy("VestingMaster", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("Core")).address,
        259200,
        19,
        (await get("UP")).address
      ]
    })
  }
}

export default func
func.tags = ["VestingMaster"]
func.dependencies = ["Core", "UP"]