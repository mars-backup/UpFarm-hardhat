import _ from 'lodash'
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { STRATEGIES } from './200_define_Strategies'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { get, getOrNull, save, execute, log } = deployments
  const { deployer } = await getNamedAccounts()

  for (let i = 0; i < STRATEGIES.length; i++) {
    const {
      lp,
      earn,
      type,
      isCollect
    } = STRATEGIES[i]
    const collect = isCollect == true ? "_collect" : ""
    const stratName = `${type}_${lp}_Earn_${earn}${collect}`
    const poolName = `UpFarm-${stratName}`
    const pool = await getOrNull(poolName)
    if (pool) continue

    const receipt = await execute(
      "UpFarm",
      { from: deployer, log: true },
      "add",
      0,
      (await get(lp)).address,
      false,
      (await get(stratName)).address,
      true
    )

    await save(poolName, {
      abi: (await get(stratName)).abi,
      address: (await get(stratName)).address
    })
  }
}

export default func
func.tags = ["UpFarmAddPool"]
func.dependencies = [
  "UpFarm",
  "Strategies"
]