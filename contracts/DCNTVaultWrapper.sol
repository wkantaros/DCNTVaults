// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// ============ Imports ============

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/// @title Decentralized Creator Nonfungible Token Vault Wrapper (DCNT VWs)
/// @notice claimable ERC20s for NFT holders after vault expiration 
contract DCNTVaultWrapper is Ownable {

  /// ============ Immutable storage ============

  /// @notice vault token to be distributed to token holders
  IERC20 public immutable vaultDistributionToken;
  /// @notice "ticket" token held by user
  IERC721Enumerable public immutable nftVaultKey;
  /// @notice unlock date when distribution can start happening
  uint256 public immutable unlockDate;
  

  /// ============ Mutable storage ============
  
  /// @notice Mapping of addresses who have claimed tokens
  mapping(uint256 => bool) internal hasClaimedTokenId;

  /// @notice total # of tokens already released
  uint256 private _totalReleased;

  /// ============ Events ============

  /// @notice Emitted after a successful token claim
  /// @param account recipient of claim
  /// @param amount of tokens claimed
  event Claimed(address account, uint256 amount);

  /// ============ Constructor ============

  /// @notice Creates a new vault
  /// @param _vaultDistributionTokenAddress of token
  /// @param _nftVaultKeyAddress of token
  /// @param _unlockDate date of vault expiration
  constructor(
    address _vaultDistributionTokenAddress, 
    address _nftVaultKeyAddress,
    uint256 _unlockDate
  ) {
    vaultDistributionToken = IERC20(_vaultDistributionTokenAddress);
    nftVaultKey = IERC721Enumerable(_nftVaultKeyAddress);
    unlockDate = _unlockDate;
  }

  /// ============ Functions ============

  // returns balance of vault
  function vaultBalance() public view returns (uint256) {
    return vaultDistributionToken.balanceOf(address(this));
  }

  // returns total # of tokens already released from vault
  function totalReleased() public view returns (uint256) {
    return _totalReleased;
  }

  // (total vault balance) * (nfts_owned/total_nfts)
  function _pendingPayment(uint256 numNftVaultKeys, uint256 totalReceived) private view returns (uint256) {
    return (totalReceived * numNftVaultKeys) / nftVaultKey.totalSupply();
  }

  // claim all the tokens for a key
  function claim(address to, uint256 tokenId) external {
    require(block.timestamp >= unlockDate, "vault is still locked");
    require(vaultBalance() > 0, "vault is empty");
    require(nftVaultKey.ownerOf(tokenId) == to, "address does not own token");
    require(!hasClaimedTokenId[tokenId], "token already claimed");

    // mark it claimed and send token
    hasClaimedTokenId[tokenId] = true;
    uint256 amount = _pendingPayment(1, vaultBalance() + totalReleased());
    require(vaultDistributionToken.transfer(to, amount), "Transfer failed");
    _totalReleased += amount;
    emit Claimed(to, amount);
  }

  // allows vault owner to claim ERC20 tokens sent to account
  // failsafe in case money needs to be taken off chain
  function drain(IERC20 token) public onlyOwner {
    token.transfer(msg.sender, token.balanceOf(address(this)));
  }
  
  function drainEth() public onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }
}
