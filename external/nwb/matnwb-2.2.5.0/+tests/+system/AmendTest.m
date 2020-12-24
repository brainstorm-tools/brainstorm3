classdef AmendTest < tests.system.NwbTestInterface
    methods (Test)
        function testAmend(testCase)
            filename = ['MatNWB.' testCase.className() '.testRoundTrip.nwb'];
            nwbExport(testCase.file, filename);
            testCase.appendContainer(testCase.file);
            nwbExport(testCase.file, filename);
            
            writeContainer = testCase.getContainer(testCase.file);
            readFile = nwbRead(filename);
            readContainer = testCase.getContainer(readFile);
            testCase.verifyContainerEqual(readContainer, writeContainer);
        end
    end
    
    methods (Abstract)
        appendContainer(testCase, file);
    end
end

