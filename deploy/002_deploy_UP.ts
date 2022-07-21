import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()

  const token = await getOrNull("UP")
  if (token) {
    log(`reusing "UP" at ${token.address}`)
  } else {
    await deploy("UP", {
      from: deployer,
      contract: "UpToken",
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        deployer,
        (await get("Core")).address
      ]
    })
  }
}
export default func
func.tags = ["UP"]