// SPDX-License-Identifier: BlueOak-1.0.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/p0/interfaces/IERC20Receiver.sol";
import "contracts/p0/interfaces/IMain.sol";
import "contracts/p0/libraries/Auction.sol";
import "contracts/p0/TraderP0.sol";
import "contracts/p0/main/VaultHandlerP0.sol";

/// The RevenueTrader converts all asset balances at its address to a single target asset,
/// and transfers this to either the Furnace or StRSR.
contract RevenueTraderP0 is TraderP0 {
    using SafeERC20 for IERC20;

    IAsset private assetToBuy;

    constructor(VaultHandlerP0 main_, IAsset assetToBuy_) TraderP0(main_) {
        assetToBuy = assetToBuy_;
    }

    function poke() public override returns (bool) {
        return TraderP0.poke() || _startRevenueAuctions();
    }

    /// Start auctions selling all asset types to purchase RSR or RToken
    /// @return trading Whether an auction was launched
    function _startRevenueAuctions() private returns (bool trading) {
        IAsset[] memory assets = main.allAssets(); // includes RToken/RSR/COMP/AAVE
        trading = false;
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20 erc20 = assets[i].erc20();
            uint256 bal = erc20.balanceOf(address(this));

            if (assets[i] == assetToBuy) {
                erc20.safeApprove(address(main), bal);
                main.distribute(erc20, address(this), bal);
            } else {
                // If not dust, trade the non-target asset for the target asset
                bool launch;
                Auction.Info memory auction;

                (launch, auction) = _prepareAuctionSell(assets[i], assetToBuy, bal, fate);
                if (launch) {
                    trading = true;
                    _launchAuction(auction);
                }
            }
        }
    }
}
