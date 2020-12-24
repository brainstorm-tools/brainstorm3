classdef NwbTestInterface < matlab.unittest.TestCase
   properties
        %     registry
        file
        root;
    end
    
    methods (TestClassSetup)
        function setupClass(testCase)
            rootPath = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(rootPath));
            testCase.root = rootPath;
        end
    end
    
    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            schemaPath = fullfile(testCase.root, 'nwb-schema');
            
            generateCore(...
                fullfile(schemaPath, 'hdmf-common-schema', 'common', 'namespace.yaml'),...
                fullfile(schemaPath, 'core', 'nwb.namespace.yaml'));
            testCase.file = NwbFile( ...
                'session_description', 'a test NWB File', ...
                'identifier', 'TEST123', ...
                'session_start_time', '2018-12-02T12:57:27.371444-08:00', ...
                'file_create_date', '2017-04-15T12:00:00.000000-08:00',...
                'timestamps_reference_time', '2018-12-02T12:57:27.371444-08:00');
            testCase.addContainer(testCase.file);
        end
    end
    
    methods
        function n = className(testCase)
            classSplit = strsplit(class(testCase), '.');
            n = classSplit{end};
        end
        
        function verifyContainerEqual(testCase, actual, expected)
            testCase.verifyEqual(class(actual), class(expected));
            props = properties(actual);
            for i = 1:numel(props)
                prop = props{i};
                if strcmp(prop, 'file_create_date')
                    continue;
                end
                val1 = actual.(prop);
                val2 = expected.(prop);
                failmsg = ['Values for property ''' prop ''' are not equal'];
                if startsWith(class(val1), 'types.')...
                        && ~startsWith(class(val1), 'types.untyped')
                    verifyContainerEqual(testCase, val1, val2);
                elseif isa(val1, 'types.untyped.Set')
                    verifySetEqual(testCase, val1, val2, failmsg);
                elseif isdatetime(val1)
                    testCase.verifyEqual(char(val1), char(val2));
                else
                    if isa(val1, 'types.untyped.DataStub')
                        trueval = val1.load();
                    else
                        trueval = val1;
                    end
                    
                    if isvector(val2) && isvector(trueval) && numel(val2) == numel(trueval)
                        trueval = reshape(trueval, size(val2));
                    end
                    testCase.verifyEqual(trueval, val2, failmsg);
                end
            end
        end
        
        function verifySetEqual(testCase, actual, expected, failmsg)
            testCase.verifyEqual(class(actual), class(expected));
            ak = actual.keys();
            ek = expected.keys();
            verifyTrue(testCase, isempty(setxor(ak, ek)), failmsg);
            for i=1:numel(ak)
                key = ak{i};
                verifyContainerEqual(testCase, actual.get(key), ...
                    expected.get(key)); 
            end
        end
        
        function verifyUntypedEqual(testCase, actual, expected)
            testCase.verifyEqual(class(actual), class(expected));
            props = properties(actual);
            for i = 1:numel(props)
                prop = props{i};
                val1 = actual.(prop);
                val2 = expected.(prop);
                if isa(val1, 'types.core.NWBContainer') || isa(val1, 'types.core.NWBData')
                    verifyContainerEqual(testCase, val1, val2);
                else
                    testCase.verifyEqual(val1, val2, ...
                        ['Values for property ''' prop ''' are not equal']);
                end
            end
        end
        
    end
    
    methods(Abstract)
        addContainer(testCase, file);
        c = getContainer(testCase, file);
    end
end

