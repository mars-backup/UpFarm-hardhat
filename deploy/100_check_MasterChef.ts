import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute, get, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  const chef = await getOrNull("MasterChef")
  if (chef) {
    log(`reusing "MasterChef" at ${chef.address}`)
  } else {
    await deploy("SyrupBar", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("CAKE")).address
      ]
    })

    await deploy("MasterChef", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get("CAKE")).address,
        (await get("SyrupBar")).address,
        deployer,
        "1000000000000000000",
        0
      ]
    })
/*
    await execute(
      "CAKE",
      { from: deployer, log: true },
      "transferOwnership",
      (await get("MasterChef")).address
    )
*/
    await execute(
      "SyrupBar",
      { from: deployer, log: true },
      "transferOwnership",
      (await get("MasterChef")).address
    )
  }
}
export default func
func.tags = ["MasterChef"]
func.dependencies = ["CAKE"]