import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

export const STRATEGIES: any[] = [
  {
    lp: "XMS",
    earn: "WBNB",
    type: "StrategyMars",
    pid: 0,
    allocPoint: 80,
    farm: "LiquidityMiningMasterBNB",
    earnedToToken0Router0: "MarsSwapRouter"
  },
  {
    lp: "XMS",
    earn: "CAKE",
    type: "StrategyMars",
    pid: 0,
    allocPoint: 20,
    farm: "LiquidityMiningMasterCAKE",
    earnedToToken0Router0: "PancakeSwapRouter",
    earnedToToken0Router1: "MarsSwapRouter",
    earnedToToken0Path0: [ "CAKE", "WBNB" ],
    earnedToToken0Path1: [ "WBNB", "XMS" ],
  },
  {
    lp: "XMS",
    earn: "ETH",
    type: "StrategyMars",
    pid: 0,
    allocPoint: 50,
    farm: "LiquidityMiningMasterETH",
    earnedToToken0Router0: "PancakeSwapRouter",
    earnedToToken0Router1: "MarsSwapRouter",
    earnedToToken0Path0: [ "ETH", "WBNB" ],
    earnedToToken0Path1: [ "WBNB", "XMS" ],
  },
  {
    lp: "USDm",
    earn: "WBNB",
    type: "StrategyMars",
    pid: 2,
    allocPoint: 30,
    farm: "LiquidityMiningMasterBNB",
    earnedToToken0Router0: "MarsSwapRouter"
  },
  {
    lp: "USDm",
    earn: "CAKE",
    type: "StrategyMars",
    pid: 1,
    allocPoint: 20,
    farm: "LiquidityMiningMasterCAKE",
    earnedToToken0Router0: "PancakeSwapRouter",
    earnedToToken0Router1: "MarsSwapRouter",
    earnedToToken0Path0: [ "CAKE", "BUSD" ],
    earnedToToken0Path1: [ "BUSD", "USDm" ]
  },
  {
    lp: "mars_XMS-USDm",
    tokens: [ "XMS", "USDm" ],
    earn: "CAKE",
    type: "StrategyMars",
    pid: 2,
    allocPoint: 40,
    farm: "LiquidityMiningMasterCAKE",
    earnedToToken0Router0: "PancakeSwapRouter",
    earnedToToken0Router1: "MarsSwapRouter",
    earnedToToken0Path0: [ "CAKE", "WBNB" ],
    earnedToToken0Path1: [ "WBNB", "XMS" ],
    earnedToToken1Router0: "PancakeSwapRouter",
    earnedToToken1Router1: "MarsSwapRouter",
    earnedToToken1Path0: [ "CAKE", "BUSD" ],
    earnedToToken1Path1: [ "BUSD", "USDm" ]
  },
  {
    lp: "mars_XMS-BNB",
    tokens: [ "XMS", "WBNB" ],
    earn: "WBNB",
    type: "StrategyMars",
    pid: 1,
    allocPoint: 50,
    farm: "LiquidityMiningMasterBNB",
    earnedToToken0Router0: "MarsSwapRouter"
  },
  {
    lp: "mars_XMS-BNB",
    tokens: [ "XMS", "WBNB" ],
    earn: "CAKE",
    type: "StrategyMars",
    pid: 3,
    allocPoint: 60,
    farm: "LiquidityMiningMasterCAKE",
    earnedToToken0Router0: "PancakeSwapRouter",
    earnedToToken0Router1: "MarsSwapRouter",
    earnedToToken0Path0: [ "CAKE", "WBNB" ],
    earnedToToken0Path1: [ "WBNB", "XMS" ]
  },
  {
    lp: "CAKE",
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 0,
    allocPoint: 80,
    farm: "MasterChef"
  },
  {
    lp: "pcs_BUSD-BNB",
    tokens: [ "BUSD", "WBNB" ],
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 1,
    allocPoint: 20,
    farm: "MasterChef"
  },
  {
    lp: "pcs_ETH-BUSD",
    tokens: [ "ETH", "BUSD" ],
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 2,
    allocPoint: 50,
    farm: "MasterChef"
  },
  {
    lp: "pcs_CAKE-BNB",
    tokens: [ "CAKE", "WBNB" ],
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 3,
    allocPoint: 30,
    farm: "MasterChef"
  },
  {
    lp: "pcs_CAKE-BUSD",
    tokens: [ "CAKE", "BUSD" ],
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 4,
    allocPoint: 20,
    farm: "MasterChef"
  },
  {
    lp: "XMS",
    earn: "WBNB",
    type: "StrategyMars",
    pid: 0,
    allocPoint: 40,
    farm: "LiquidityMiningMasterBNB",
    isCollect: true
  },
  {
    lp: "XMS",
    earn: "CAKE",
    type: "StrategyMars",
    pid: 0,
    allocPoint: 50,
    farm: "LiquidityMiningMasterCAKE",
    isCollect: true
  },
  {
    lp: "XMS",
    earn: "ETH",
    type: "StrategyMars",
    pid: 0,
    allocPoint: 60,
    farm: "LiquidityMiningMasterETH",
    isCollect: true
  },
  {
    lp: "USDm",
    earn: "WBNB",
    type: "StrategyMars",
    pid: 2,
    allocPoint: 80,
    farm: "LiquidityMiningMasterBNB",
    isCollect: true
  },
  {
    lp: "USDm",
    earn: "CAKE",
    type: "StrategyMars",
    pid: 1,
    allocPoint: 20,
    farm: "LiquidityMiningMasterCAKE",
    isCollect: true
  },
  {
    lp: "mars_XMS-USDm",
    earn: "CAKE",
    type: "StrategyMars",
    pid: 2,
    allocPoint: 50,
    farm: "LiquidityMiningMasterCAKE",
    isCollect: true
  },
  {
    lp: "mars_XMS-BNB",
    earn: "WBNB",
    type: "StrategyMars",
    pid: 1,
    allocPoint: 30,
    farm: "LiquidityMiningMasterBNB",
    isCollect: true
  },
  {
    lp: "mars_XMS-BNB",
    earn: "CAKE",
    type: "StrategyMars",
    pid: 3,
    allocPoint: 20,
    farm: "LiquidityMiningMasterCAKE",
    isCollect: true
  },
  {
    lp: "CAKE",
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 0,
    allocPoint: 40,
    farm: "MasterChef",
    isCollect: true
  },
  {
    lp: "pcs_BUSD-BNB",
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 1,
    allocPoint: 50,
    farm: "MasterChef",
    isCollect: true
  },
  {
    lp: "pcs_ETH-BUSD",
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 2,
    allocPoint: 60,
    farm: "MasterChef",
    isCollect: true
  },
  {
    lp: "pcs_CAKE-BNB",
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 3,
    allocPoint: 100,
    farm: "MasterChef",
    isCollect: true
  },
  {
    lp: "pcs_CAKE-BUSD",
    earn: "CAKE",
    type: "StrategyPCS",
    pid: 4,
    allocPoint: 100,
    farm: "MasterChef",
    isCollect: true
  },
  {
    lp: "UP",
    earn: "CAKE",
    type: "StrategyMars",
    pid: 0,
    allocPoint: 80,
    farm: "StakingRewardsCAKE",
    earnedToUpPath0: [ "CAKE", "UP" ],
    earnedToToken0Path0: [ "CAKE", "UP" ]
  },
  {
    lp: "BSW",
    earn: "BSW",
    type: "StrategyPCS",
    pid: 0,
    allocPoint: 20,
    farm: "MasterChefBSW",
    cake: "BSW",
    buyBackRouter0: "BiswapRouter",
    buyBackRouter1: "PancakeSwapRouter",
    earnedToUpPath0: [ "BSW", "WBNB" ],
    earnedToUpPath1: [ "WBNB", "CAKE", "UP" ]
  },
  {
    lp: "bsw_BSW-BNB",
    tokens: [ "BSW", "WBNB" ],
    earn: "BSW",
    type: "StrategyPCS",
    pid: 1,
    allocPoint: 50,
    farm: "MasterChefBSW",
    cake: "BSW",
    wantRouter: "BiswapRouter",
    buyBackRouter0: "BiswapRouter",
    buyBackRouter1: "PancakeSwapRouter",
    earnedToUpPath0: [ "BSW", "WBNB" ],
    earnedToUpPath1: [ "WBNB", "CAKE", "UP" ],
    earnedToToken1Router0: "BiswapRouter",
    earnedToToken1Path0: [ "BSW", "WBNB" ]
  },
  {
    lp: "bsw_BTCB-USDT",
    tokens: [ "BTCB", "USDT" ],
    earn: "BSW",
    type: "StrategyPCS",
    pid: 2,
    allocPoint: 50,
    farm: "MasterChefBSW",
    cake: "BSW",
    wantRouter: "BiswapRouter",
    buyBackRouter0: "BiswapRouter",
    buyBackRouter1: "PancakeSwapRouter",
    earnedToUpPath0: [ "BSW", "WBNB" ],
    earnedToUpPath1: [ "WBNB", "CAKE", "UP" ],
    earnedToToken0Router0: "BiswapRouter",
    earnedToToken0Path0: [ "BSW", "WBNB", "BTCB" ],
    earnedToToken1Router0: "BiswapRouter",
    earnedToToken1Path0: [ "BSW", "USDT" ]
  },
  {
    lp: "BSW",
    earn: "BSW",
    type: "StrategyPCS",
    pid: 0,
    allocPoint: 20,
    farm: "MasterChefBSW",
    cake: "BSW",
    isCollect: true
  },
  {
    lp: "bsw_BSW-BNB",
    earn: "BSW",
    type: "StrategyPCS",
    pid: 1,
    allocPoint: 50,
    farm: "MasterChefBSW",
    cake: "BSW",
    isCollect: true
  },
  {
    lp: "bsw_BTCB-USDT",
    earn: "BSW",
    type: "StrategyPCS",
    pid: 2,
    allocPoint: 50,
    farm: "MasterChefBSW",
    cake: "BSW",
    isCollect: true
  }
]

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {}
export default func
func.tags = ["DefineStrategies"]