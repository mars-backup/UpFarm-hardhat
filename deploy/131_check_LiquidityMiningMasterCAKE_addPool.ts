import moment from 'moment'
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"

const POOLS = [
  {
    name: 'XMS',
    allocPoint: 1000
  },
  {
    name: 'USDm',
    allocPoint: 1000
  },
  {
    name: 'mars_XMS-USDm',
    allocPoint: 1000
  },
  {
    name: 'mars_XMS-BNB',
    allocPoint: 1000
  },
]

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { get, execute, getOrNull, save } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  for (let i = 0; i < POOLS.length; i++) {
    const { name, allocPoint } = POOLS[i]
    const poolName = 'LiquidityMiningMasterCAKE-' + name
    const pool = await getOrNull(poolName)
    if (pool) continue

    await execute(
      "LiquidityMiningMasterCAKE",
      { from: deployer, log: true },
      "addPool",
      allocPoint,
      (await get(name)).address,
      false,
      true
    )
    await save(poolName, {
      abi: (await get("BUSD")).abi,
      address: (await get("LiquidityMiningMasterCAKE")).address
    })
  }
}

export default func
func.tags = ["LiquidityMiningMasterCAKEAddPool"]
func.dependencies = ["LiquidityMiningMasterCAKE"]