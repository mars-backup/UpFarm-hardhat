import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, execute, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()

  const core = await getOrNull("Core")
  if (core) {
    log(`reusing "Core" at ${core.address}`)
  } else {
    await deploy("Core", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    })
  }
}
export default func
func.tags = ["Core"]