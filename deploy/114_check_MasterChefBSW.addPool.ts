import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const PAIRS = [
  {
    name: 'bsw_BSW-BNB'
  },
  {
    name: 'bsw_BTCB-USDT'
  }
]

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { get, execute, getOrNull, save, log } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  for (let i = 0; i < PAIRS.length; i++) {
    const { name } = PAIRS[i]
    const poolName = 'MasterChefBSWPool-' + name
    const pool = await getOrNull(poolName)
    if (pool) continue

    await execute(
      "MasterChefBSW",
      { from: deployer, log: true },
      "add",
      1000,
      (await get(name)).address,
      true
    )
    await save(poolName, {
      abi: (await get("BUSD")).abi,
      address: (await get("MasterChefBSW")).address
    })
  }
}

export default func
func.tags = ["MasterChefBSWAddPool"]
func.dependencies = ["LPs"]