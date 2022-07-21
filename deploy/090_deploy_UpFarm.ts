import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, getOrNull, log, get } = deployments
  const { deployer } = await getNamedAccounts()

  const farm = await getOrNull("UpFarm")
  if (farm) {
    log(`reusing "UpFarm" at ${farm.address}`)
  } else {
    await deploy("UpFarm", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("Core")).address,
        (await get("UP")).address,
        (await get("VestingMaster")).address,
        "200000000000000000",
        0
      ]
    })
  }
}

export default func
func.tags = ["UpFarm"]
func.dependencies = ["Core","VestingMaster","UP"]