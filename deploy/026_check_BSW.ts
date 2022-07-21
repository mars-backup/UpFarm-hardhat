import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  const token = await getOrNull("BSW")
  if (token) {
    log(`reusing "BSW" at ${token.address}`)
  } else {
    const result = await deploy("BSW", {
      from: deployer,
      contract: "BSWToken",
      log: true,
      skipIfAlreadyDeployed: true
    })

    if (result.newlyDeployed) {
      await execute(
        "BSW",
        { from: deployer, log: true },
        "addMinter",
        deployer
      )
    }
  }
}
export default func
func.tags = ["BSW"]