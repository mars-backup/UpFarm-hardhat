import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get, getOrNull, log, read } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  const router = await getOrNull("BiswapRouter")
  if (router) {
    log(`reusing "BiswapRouter" at ${router.address}`)
  } else {
    await deploy("BiswapFactory", {
      from: deployer,
      contract: "BiswapFactory",
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        deployer
      ]
    })

    await deploy("BiswapRouter", {
      from: deployer,
      contract: "BiswapRouter02",
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("BiswapFactory")).address,
        (await get("WBNB")).address
      ]
    })
  }
}
export default func
func.tags = ["BiswapRouter"]
func.dependencies = ["WBNB"]