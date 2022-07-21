import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  const router = await getOrNull("PancakeSwapRouter")
  if (router) {
    log(`reusing "PancakeSwapRouter" at ${router.address}`)
  } else {
    await deploy("PancakeSwapFactory", {
      from: deployer,
      contract: "MarsSwapFactory",
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("Core")).address
      ]
    })

    await deploy("PancakeSwapRouter", {
      from: deployer,
      contract: "MarsSwapRouter",
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("PancakeSwapFactory")).address,
        (await get("WBNB")).address
      ]
    })
  }
}
export default func
func.tags = ["PancakeSwapRouter"]
func.dependencies = ["Core","WBNB"]