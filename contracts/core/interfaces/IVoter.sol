// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

interface IVoter {
    function gauges(address _pool) external view returns (address);

    function gaugeToFees(address _gauge) external view returns (address);

    function gaugeToBribes(address _gauge) external view returns (address);

    function createGauge(address _poolFactory, address _pool) external returns (address);

    function distribute(address gauge) external;

    function isAlive(address _gauge) external view returns (bool);
}
