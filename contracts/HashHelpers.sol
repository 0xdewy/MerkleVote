pragma solidity 0.4.24;

contract HashHelpers {


  function getVoteID(address _executionAddress, bytes4 _methodID, bytes32 _parameterHash)
  public
  pure
  returns (bytes32) {
    return keccak256(abi.encodePacked(_executionAddress, _methodID, _parameterHash));
  }

  function getMethodID(string _functionString)
  public
  pure
  returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(_functionString)));
  }

  function getParameterHash(address _paramOne, uint _paramTwo)
  public
  pure
  returns (bytes32) {
    return keccak256(abi.encodePacked(_paramOne, _paramTwo));
  }


}
