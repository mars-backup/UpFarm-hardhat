import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute, get, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  const chef = await getOrNull("MasterChefBSW")
  if (chef) {
    log(`reusing "MasterChefBSW" at ${chef.address}`)
  } else {
    await deploy("MasterChefBSW", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("BSW")).address,
        deployer,
        deployer,
        deployer,
        "1000000000000000000",
        0,
        857000,
        90000,
        43000,
        10000
      ]
    })

    await execute(
      "BSW",
      { from: deployer, log: true },
      "addMinter",
      (await get("MasterChefBSW")).address
    )
  }
}
export default func
func.tags = ["MasterChefBSW"]
func.dependencies = ["BSW"]