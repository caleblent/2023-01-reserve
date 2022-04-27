// SPDX-License-Identifier: BlueOak-1.0.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "contracts/plugins/assets/abstract/CompoundOracleMixin.sol";
import "contracts/interfaces/IAsset.sol";
import "contracts/libraries/Fixed.sol";

// ==== External Interfaces ====
// See: https://github.com/aave/protocol-v2/tree/master/contracts/interfaces
interface IAaveLendingPool {
    function getAddressesProvider() external view returns (ILendingPoolAddressesProvider);
}

interface ILendingPoolAddressesProvider {
    function getPriceOracle() external view returns (IAaveOracle);
}

interface IAaveOracle {
    // solhint-disable-next-line func-name-mixedcase
    function WETH() external view returns (address);

    /// @return {qETH/tok} The price of the `token` in ETH with 18 decimals
    function getAssetPrice(address token) external view returns (uint256);
}

// ==== End External Interfaces ====

abstract contract AaveOracleMixin is CompoundOracleMixin {
    using FixLib for int192;

    IAaveLendingPool public aaveLendingPool;

    // solhint-disable-next-line func-name-mixedcase
    function __AaveOracleMixin_init(IComptroller comptroller_, IAaveLendingPool aaveLendingPool_)
        internal
        onlyInitializing
    {
        __CompoundOracleMixin_init(comptroller_);
        aaveLendingPool = aaveLendingPool_;
    }

    /// @return {UoA/erc20}
    function consultOracle(IERC20Metadata erc20_) public view override returns (int192) {
        // Aave keeps their prices in terms of ETH
        IAaveOracle aaveOracle = aaveLendingPool.getAddressesProvider().getPriceOracle();
        uint256 p = aaveOracle.getAssetPrice(address(erc20_));

        if (p == 0) {
            revert PriceIsZero();
        }

        uint256 ethPrice = comptroller.oracle().price("ETH"); // {microUoA/ETH}
        uint256 ethNorm = aaveOracle.getAssetPrice(aaveOracle.WETH()); // {qETH/ETH}

        // {UoA/erc20} = {qETH/erc20} * {microUoA/ETH} / {qETH/ETH} / {microUoA/UoA}
        return shiftl_toFix(mulDiv256(p, ethPrice, ethNorm), -6);
    }
}
