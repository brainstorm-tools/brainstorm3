function verifySetEqual(testCase, actual, expected, failmsg)
testCase.verifyEqual(class(actual), class(expected));
ak = actual.keys();
ek = expected.keys();
verifyTrue(testCase, isempty(setxor(ak, ek)), failmsg);
for i=1:numel(ak)
    key = ak{i};
    tests.util.verifyContainerEqual(testCase, actual.get(key), ...
        expected.get(key));
end
end