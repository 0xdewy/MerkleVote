# MerkleVote
A way to prove token balances using a merkle tree snapshot.  

### Token Snapshot
The contract receives a list of tokenholders and the token address and creates a merkle tree by looping through all token holders.

Each leaf of the tree consists of a ethereum address and their token balance
```javascript
sha3(userAddress, tokenBalance)
```

When generating the merkle tree, the token total supply is counted and must match what the token contract returns, to ensure no balances are missing.

### How to use

You can setup a vote using `createVote`:
```javascript
function createVote(address[] _tokenHolders, bytes32 _voteID)
public
returns (bool) {
    bytes32[] memory elements = prepareTree(_tokenHolders);
    bytes32 root = createRootProof(elements);
    merkleRoot[_voteID] = root;
    return true;
}
```

Once the token snapshot is created and the merkle root is stored you can vote using `vote()`:
```javascript
function vote(bytes32 _voteID, uint _balanceAtSnapshot, bytes32 _root, bytes32[] _proof)
external
returns (bool) {
  require(merkleRoot[_voteID] == _root);
  require(!voted[keccak256(abi.encodePacked(_voteID, msg.sender))]);
  bytes32 computedElement = keccak256(abi.encodePacked(msg.sender, _balanceAtSnapshot));
  require(verifyProof(_proof, _root, computedElement));
  numVotes[_voteID] += _balanceAtSnapshot;
  voted[keccak256(abi.encodePacked(_voteID, msg.sender))] = true;
  return true;
}
```
`proof` = A list of sibling elements that let you recreate that branch of the merkle tree until the root is reached
`root` = The root hash of the merkle tree (stored on-chain)
