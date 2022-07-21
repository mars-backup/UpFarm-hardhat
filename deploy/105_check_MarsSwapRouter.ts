import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, getOrNull, log, read } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  const router = await getOrNull("MarsSwapRouter")
  if (router) {
    log(`reusing "MarsSwapRouter" at ${router.address}`)
  } else {
    await deploy("MarsSwapFactory", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("Core")).address
      ]
    })

    await deploy("MarsSwapRouter", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("MarsSwapFactory")).address,
        (await get("WBNB")).address
      ]
    })
  }
}
export default func
func.tags = ["MarsSwapRouter"]
func.dependencies = ["Core","WBNB"]