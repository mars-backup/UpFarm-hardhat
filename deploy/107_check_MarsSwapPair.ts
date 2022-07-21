import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  const pair = await getOrNull("MarsSwapPair")
  if (pair) {
    log(`reusing "MarsSwapPair" at ${pair.address}`)
  } else {
    await deploy("MarsSwapPair", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    })
  }
}
export default func
func.tags = ["MarsSwapPair"]