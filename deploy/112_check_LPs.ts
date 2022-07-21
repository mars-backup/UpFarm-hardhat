import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"
import BigNumber from "bignumber.js"

const PAIRS = [
  {
    name: 'mars_XMS-USDm',
    tokens: ['XMS','USDm'],
    router: 'MarsSwapRouter',
    factory: 'MarsSwapFactory',
    amounts: [ new BigNumber(1e20).times(2), new BigNumber(1e20) ]
  },
  {
    name: 'mars_XMS-BNB',
    tokens: ['XMS','WBNB'],
    router: 'MarsSwapRouter',
    factory: 'MarsSwapFactory',
    amounts: [ new BigNumber(1e19).times(1200), new BigNumber(1e19) ]
  },
  {
    name: 'pcs_BUSD-BNB',
    tokens: ['BUSD','WBNB'],
    router: 'PancakeSwapRouter',
    factory: 'PancakeSwapFactory',
    amounts: [ new BigNumber(1e19).times(400), new BigNumber(1e19) ]
  },
  {
    name: 'pcs_ETH-BUSD',
    tokens: ['ETH','BUSD'],
    router: 'PancakeSwapRouter',
    factory: 'PancakeSwapFactory',
    amounts: [ new BigNumber(1e20), new BigNumber(1e20).times(4000) ]
  },
  {
    name: 'pcs_CAKE-BNB',
    tokens: ['CAKE','WBNB'],
    router: 'PancakeSwapRouter',
    factory: 'PancakeSwapFactory',
    amounts: [ new BigNumber(1e19).times(30), new BigNumber(1e19) ]
  },
  {
    name: 'pcs_CAKE-BUSD',
    tokens: ['CAKE','BUSD'],
    router: 'PancakeSwapRouter',
    factory: 'PancakeSwapFactory',
    amounts: [ new BigNumber(1e22), new BigNumber(1e22).times(20) ]
  },
  {
    name: 'bsw_BSW-BNB',
    tokens: ['BSW','WBNB'],
    router: 'BiswapRouter',
    factory: 'BiswapFactory',
    amounts: [ new BigNumber(1e18).times(300), new BigNumber(1e17) ]
  },
  {
    name: 'bsw_BTCB-USDT',
    tokens: ['BTCB','USDT'],
    router: 'BiswapRouter',
    factory: 'BiswapFactory',
    amounts: [ new BigNumber(1e18), new BigNumber(1e18).times(40000) ]
  },
]

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { get, execute, getOrNull, save, log, read } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  for (let i = 0; i < PAIRS.length; i++) {
    const { name, tokens, router, amounts, factory } = PAIRS[i]
    const pair = await getOrNull(name)
    if (pair) continue

    const rt = (await get(router)).address
    for (let j = 0; j < 2; j++) {
      await execute(
        tokens[j],
        { from: deployer, log: true },
        "approve",
        rt,
        amounts[j].toString(10)
      )
    }

    const token0Address = (await get(tokens[0])).address
    const token1Address = (await get(tokens[1])).address

    const receipt = await execute(
      router,
      { from: deployer, log: true },
      "addLiquidity",
      token0Address,
      token1Address,
      amounts[0].toString(10),
      amounts[1].toString(10),
      0,
      0,
      deployer,
      "1000000000000000000"
    )

    const p = await read(factory, "getPair", token0Address, token1Address)
/*
    const event = receipt?.events?.find(
      (e: any) => e["event"] == "PairCreated",
    )
    const p = event["args"]["pair"]
*/
    log(`deployed LP at ${p}`)
    await save(name, {
      abi: (await get("MarsSwapPair")).abi,
      address: p,
    })
  }
}

export default func
func.tags = ["LPs"]
func.dependencies = ["Tokens"]