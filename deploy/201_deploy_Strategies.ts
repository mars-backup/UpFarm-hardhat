import _ from 'lodash'
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { STRATEGIES } from './200_define_Strategies'

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, get, getOrNull, read, execute, log } = deployments
  const { deployer } = await getNamedAccounts()

  const coreAddress = (await get("Core")).address
  const wbnbAddress = (await get("WBNB")).address
  const UPFarmAddress = (await get("UpFarm")).address
  const UPAddress = (await get("UP")).address
  const cakeAddress = (await get("CAKE")).address
  const pancakeSwapRouterAddress = (await get("PancakeSwapRouter")).address
  const marsSwapRouterAddress = (await get("MarsSwapRouter")).address
  const rewardsDistributorAddress = (await get("RewardsDistributor")).address

  for (let i = 0; i < STRATEGIES.length; i++) {
    let {
      lp,
      tokens,
      earn,
      type,
      pid,
      farm,
      isCollect,
      earnedToUpPath0,
      earnedToUpPath1,
      earnedToToken0Path0,
      earnedToToken0Path1,
      earnedToToken1Path0,
      earnedToToken1Path1,
      buyBackRouter0,
      buyBackRouter1,
      earnedToToken0Router0,
      earnedToToken0Router1,
      earnedToToken1Router0,
      earnedToToken1Router1,
      controllerFee,
      buyBackRate,
      entranceFeeFactor,
      withdrawFeeFactor,
      cake,
      wantRouter
    } = STRATEGIES[i]
    const collect = isCollect == true ? "_collect" : ""
    const stratName = `${type}_${lp}_Earn_${earn}${collect}`
    const strat = await getOrNull(stratName)
    if (strat) continue

    const lpAddress = (await get(lp)).address
    const earnAddress = (await get(earn)).address
    const isLP = lp.includes('-')
    const token0Address = isLP ? (await read(lp, "token0")) : lpAddress
    const token1Address = isLP ? (await read(lp, "token1")) : lpAddress
    if (isLP && !_.isNil(tokens)) {
      const t0 = (await get(tokens[0])).address
      const reverse = t0 != token0Address
      if (reverse) {
        [ earnedToToken0Path0, earnedToToken1Path0 ] = [ earnedToToken1Path0, earnedToToken0Path0 ];
        [ earnedToToken0Path1, earnedToToken1Path1 ] = [ earnedToToken1Path1, earnedToToken0Path1 ];
        [ earnedToToken0Router0, earnedToToken1Router0 ] = [ earnedToToken1Router0, earnedToToken0Router0 ];
        [ earnedToToken0Router1, earnedToToken1Router1 ] = [ earnedToToken1Router1, earnedToToken0Router1 ];
      }
    }

    const farmAddress = (await get(farm)).address

    let _buyBackRouter0Address = buyBackRouter0 ? (await get(buyBackRouter0)).address : pancakeSwapRouterAddress
    let _buyBackRouter1Address = buyBackRouter1 ? (await get(buyBackRouter1)).address : ZERO_ADDRESS

    let _earnedToUpPath0 = earnedToUpPath0 || []
    let _earnedToUpPath1 = earnedToUpPath1 || []
    if (!isCollect && _.size(_earnedToUpPath0) == 0 && _.size(_earnedToUpPath1) == 0) {
      if (earn == 'XMS' || earn == 'USDm') {
        _buyBackRouter0Address = marsSwapRouterAddress
        _earnedToUpPath0 = [ earn, "WBNB", "UP" ]
      } else if (earn == 'WBNB') {
        _buyBackRouter0Address = marsSwapRouterAddress
        _earnedToUpPath0 = [ "WBNB", "UP" ]
      } else {
        _earnedToUpPath0 = [ earn, "WBNB" ]
        _buyBackRouter1Address = marsSwapRouterAddress
        _earnedToUpPath1 = [ "WBNB", "UP" ]
      }
    }
    if (_.size(_earnedToUpPath0) > 0) {
        _earnedToUpPath0 = await Promise.all(_earnedToUpPath0.map(async (v: any) => (await get(v)).address))
    }

    if (_.size(_earnedToUpPath1) > 0) {
      _earnedToUpPath1 = await Promise.all(_earnedToUpPath1.map(async (v: any) => (await get(v)).address))
    }

    let _earnedToToken0Router0Address = earnedToToken0Router0 ? (await get(earnedToToken0Router0)).address : pancakeSwapRouterAddress
    let _earnedToToken0Router1Address = earnedToToken0Router1 ? (await get(earnedToToken0Router1)).address : ZERO_ADDRESS
    let _earnedToToken0Path0 = earnedToToken0Path0 || []
    let _earnedToToken0Path1 = earnedToToken0Path1 || []
    if (_.size(_earnedToToken0Path0) == 0 && _.size(_earnedToToken0Path1) == 0) {
      if (!isCollect && earnAddress != token0Address) {
        _earnedToToken0Path0 = [ earnAddress, token0Address ]
      }
    } else {
      _earnedToToken0Path0 = await Promise.all(_earnedToToken0Path0.map(async (v: any) => (await get(v)).address))
    }

    if (_.size(_earnedToToken0Path1) > 0) {
      _earnedToToken0Path1 = await Promise.all(_earnedToToken0Path1.map(async (v: any) => (await get(v)).address))
    }

    if (_.size(_earnedToToken0Path0) == 0) {
      _earnedToToken0Router0Address = ZERO_ADDRESS
    }

    if (_.size(_earnedToToken0Path1) == 0) {
      _earnedToToken0Router1Address = ZERO_ADDRESS
    }

    let _earnedToToken1Router0Address = earnedToToken1Router0 ? (await get(earnedToToken1Router0)).address : pancakeSwapRouterAddress
    let _earnedToToken1Router1Address = earnedToToken1Router1 ? (await get(earnedToToken1Router1)).address : ZERO_ADDRESS
    let _earnedToToken1Path0 = earnedToToken1Path0 || []
    let _earnedToToken1Path1 = earnedToToken1Path1 || []
    if (_.size(_earnedToToken1Path0) == 0 && _.size(_earnedToToken1Path1) == 0) {
      if (!isCollect && earnAddress != token1Address) {
        _earnedToToken1Path0 = [ earnAddress, token1Address ]
      }
    } else {
      _earnedToToken1Path0 = await Promise.all(_earnedToToken1Path0.map(async (v: any) => (await get(v)).address))
    }
    
    if (_.size(_earnedToToken1Path1) > 0) {
      _earnedToToken1Path1 = await Promise.all(_earnedToToken1Path1.map(async (v: any) => (await get(v)).address))
    }

    if (_.size(_earnedToToken1Path0) == 0) {
      _earnedToToken1Router0Address = ZERO_ADDRESS
    }

    if (_.size(_earnedToToken1Path1) == 0) {
      _earnedToToken1Router1Address = ZERO_ADDRESS
    }

    const _controllerFee = !_.isNil(controllerFee) ? controllerFee : (isCollect ? 0 : 300)
    const _buyBackRate = !_.isNil(buyBackRate) ? buyBackRate : (isCollect ? 0 : 200)
    const _entranceFeeFactor = !_.isNil(entranceFeeFactor) ? entranceFeeFactor : 9990
    const _withdrawFeeFactor = !_.isNil(withdrawFeeFactor) ? withdrawFeeFactor : 9990

    const _cakeAddress = !_.isNil(cake) ? (await get(cake)).address : cakeAddress
    let _wantRouter = ZERO_ADDRESS
    if (_.isNil(wantRouter)) {
      if (token0Address == token1Address) {
        _wantRouter = ZERO_ADDRESS
      } else if (type == "StrategyPCS") {
        _wantRouter = pancakeSwapRouterAddress
      } else if (type == "StrategyMars") {
        _wantRouter = marsSwapRouterAddress
      }
    } else {
      _wantRouter = (await get(wantRouter)).address
    }

    let _wbnbAddress = earnAddress == wbnbAddress ? wbnbAddress : ZERO_ADDRESS

    if (isCollect) {
      _buyBackRouter0Address = ZERO_ADDRESS
      _buyBackRouter1Address = ZERO_ADDRESS
      _earnedToToken0Router0Address = ZERO_ADDRESS
      _earnedToToken0Router1Address = ZERO_ADDRESS
      _earnedToToken1Router0Address = ZERO_ADDRESS
      _earnedToToken1Router1Address = ZERO_ADDRESS
      _earnedToUpPath0 = []
      _earnedToUpPath1 = []
      _earnedToToken0Path0 = []
      _earnedToToken0Path1 = []
      _earnedToToken1Path0 = []
      _earnedToToken1Path1 = []
      _wantRouter = ZERO_ADDRESS
      _wbnbAddress = ZERO_ADDRESS
    }

    let args
    if (type == "StrategyPCS") {
      args = [
        [
          coreAddress,
          _wbnbAddress,
          UPFarmAddress,
          UPAddress,
          lpAddress,
          token0Address,
          token1Address,
          earnAddress,
          farmAddress,
          rewardsDistributorAddress,
          _wantRouter,
          _earnedToToken0Router0Address,
          _earnedToToken0Router1Address,
          _earnedToToken1Router0Address,
          _earnedToToken1Router1Address,
          _buyBackRouter0Address,
          _buyBackRouter1Address
        ],
        pid,
        _cakeAddress == lpAddress,
        true,
        !_.isNil(isCollect) ? isCollect : false,
        _earnedToUpPath0,
        _earnedToUpPath1,
        _earnedToToken0Path0,
        _earnedToToken0Path1,
        _earnedToToken1Path0,
        _earnedToToken1Path1,
        _controllerFee,
        _buyBackRate,
        _entranceFeeFactor,
        _withdrawFeeFactor
      ]
    } else if (type == "StrategyMars") {
      args = [
        [
          coreAddress,
          _wbnbAddress,
          UPFarmAddress,
          UPAddress,
          lpAddress,
          token0Address,
          token1Address,
          earnAddress,
          farmAddress,
          rewardsDistributorAddress,
          _wantRouter,
          _earnedToToken0Router0Address,
          _earnedToToken0Router1Address,
          _earnedToToken1Router0Address,
          _earnedToToken1Router1Address,
          _buyBackRouter0Address,
          _buyBackRouter1Address
        ],
        pid,
        _earnedToUpPath0,
        _earnedToUpPath1,
        _earnedToToken0Path0,
        _earnedToToken0Path1,
        _earnedToToken1Path0,
        _earnedToToken1Path1,
        _controllerFee,
        _buyBackRate,
        _entranceFeeFactor,
        _withdrawFeeFactor,
        !_.isNil(isCollect) ? isCollect : false
      ]
    }

    const result = await deploy(stratName, {
      from: deployer,
      contract: type,
      log: true,
      skipIfAlreadyDeployed: true,
      args
    })

    if (result.newlyDeployed) {
      await execute(
        stratName,
        { from: deployer, log: true },
        "transferOwnership",
        UPFarmAddress
      )
    }
  }
}

export default func
func.tags = ["Strategies"]
func.dependencies = [
  "Core",
  "WBNB",
  "UpFarm",
  "UP",
  "Tokens",
  "MasterChef",
  "PancakeSwapRouter",
  "MarsSwapRouter",
  "LiquidityMiningMasterETH",
  "LiquidityMiningMasterBTCB",
  "LiquidityMiningMasterBNB",
  "LiquidityMiningMasterCAKE",
  "RewardsDistributor"
]