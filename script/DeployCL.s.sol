// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";

import {CLPool} from "contracts/core/CLPool.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";

contract DeployCL is Script {
    using stdJson for string;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);
    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public outputFilename = vm.envString("OUTPUT_FILENAME");
    string public jsonConstants;

    // loaded variables
    address public team;
    address public weth;
    address public voter;
    address public factoryRegistry;
    address public poolFactoryOwner;
    address public feeManager;

    // deployed contracts
    CLPool public poolImplementation;
    CLFactory public poolFactory;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLGauge public gaugeImplementation;
    CLGaugeFactory public gaugeFactory;
    CustomSwapFeeModule public swapFeeModule;
    CustomUnstakedFeeModule public unstakedFeeModule;

    function run() public {
        string memory root = vm.projectRoot();
        string memory basePath = concat(root, "/script/constants/");
        string memory path = concat(basePath, constantsFilename);
        jsonConstants = vm.readFile(path);

        team = abi.decode(vm.parseJson(jsonConstants, ".team"), (address));
        weth = abi.decode(vm.parseJson(jsonConstants, ".WETH"), (address));
        voter = abi.decode(vm.parseJson(jsonConstants, ".Voter"), (address));
        factoryRegistry = abi.decode(vm.parseJson(jsonConstants, ".FactoryRegistry"), (address));
        poolFactoryOwner = abi.decode(vm.parseJson(jsonConstants, ".poolFactoryOwner"), (address));
        feeManager = abi.decode(vm.parseJson(jsonConstants, ".feeManager"), (address));

        require(address(voter) != address(0)); // sanity check for constants file fillled out correctly

        vm.startBroadcast(deployerAddress);
        // deploy pool + factory
        poolImplementation = new CLPool();
        poolFactory = new CLFactory({_voter: voter, _poolImplementation: address(poolImplementation)});

        // deploy gauges
        gaugeImplementation = new CLGauge();
        gaugeFactory = new CLGaugeFactory({_voter: voter, _implementation: address(gaugeImplementation)});

        // set parameters on pool factory
        poolFactory.setGaugeFactory({
            _gaugeFactory: address(gaugeFactory),
            _gaugeImplementation: address(gaugeImplementation)
        });

        // deploy nft contracts
        nftDescriptor =
            new NonfungibleTokenPositionDescriptor({_WETH9: address(weth), _nativeCurrencyLabelBytes: bytes32("ETH")});
        nft = new NonfungiblePositionManager({
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor: address(nftDescriptor)
        });

        // set nft manager in the factories
        gaugeFactory.setNonfungiblePositionManager(address(nft));
        poolFactory.setNonfungiblePositionManager(address(nft));

        // deploy fee modules
        swapFeeModule = new CustomSwapFeeModule({_factory: address(poolFactory)});
        unstakedFeeModule = new CustomUnstakedFeeModule({_factory: address(poolFactory)});
        poolFactory.setSwapFeeModule({_swapFeeModule: address(swapFeeModule)});
        poolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(unstakedFeeModule)});

        // transfer permissions
        nft.setOwner(team);
        poolFactory.setOwner(poolFactoryOwner);
        poolFactory.setSwapFeeManager(feeManager);
        poolFactory.setUnstakedFeeManager(feeManager);
        vm.stopBroadcast();

        // write to file
        path = concat(basePath, "output/DeployCL-");
        path = concat(path, outputFilename);
        vm.writeJson(vm.serializeAddress("", "PoolImplementation", address(poolImplementation)), path);
        vm.writeJson(vm.serializeAddress("", "PoolFactory", address(poolFactory)), path);
        vm.writeJson(vm.serializeAddress("", "NonfungibleTokenPositionDescriptor", address(nftDescriptor)), path);
        vm.writeJson(vm.serializeAddress("", "NonfungiblePositionManager", address(nft)), path);
        vm.writeJson(vm.serializeAddress("", "GaugeImplementation", address(gaugeImplementation)), path);
        vm.writeJson(vm.serializeAddress("", "GaugeFactory", address(gaugeFactory)), path);
        vm.writeJson(vm.serializeAddress("", "SwapFeeModule", address(swapFeeModule)), path);
        vm.writeJson(vm.serializeAddress("", "UnstakedFeeModule", address(unstakedFeeModule)), path);
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}