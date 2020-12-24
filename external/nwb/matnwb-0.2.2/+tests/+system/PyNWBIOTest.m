classdef PyNWBIOTest < tests.system.RoundTripTest
  % Assumes PyNWB and unittest2 has been installed on the system.
  %
  % To install PyNWB, execute:
  % $ pip install pynwb
  %
  % To install unittest2, execute:
  % $ pip install unittest2
  methods(Test)
    function testOutToPyNWB(testCase)
      filename = ['MatNWB.' testCase.className() '.testOutToPyNWB.nwb'];
      nwbExport(testCase.file, filename);
      [status, cmdout] = testCase.runPyTest('testInFromMatNWB');
      if status
        testCase.verifyFail(cmdout);
      end
    end
    
    function testInFromPyNWB(testCase)
      [status, cmdout] = testCase.runPyTest('testOutToMatNWB');
      if status
        testCase.assertFail(cmdout);
      end
      filename = ['PyNWB.' testCase.className() '.testOutToMatNWB.nwb'];
      pyfile = nwbRead(filename);
      pycontainer = testCase.getContainer(pyfile);
      matcontainer = testCase.getContainer(testCase.file);
      testCase.verifyContainerEqual(pycontainer, matcontainer);
    end
  end
  
  methods
    function [status, cmdout] = runPyTest(testCase, testName)
      setenv('PYTHONPATH', fileparts(mfilename('fullpath')));
      
      envPath = fullfile('+tests', 'env.mat');
      if 2 == exist(envPath, 'file')
          Env = load(envPath, '-mat', 'pythonDir');
          
          pythonPath = fullfile(Env.pythonDir, 'python');
      else
          pythonPath = 'python';
      end
      
      cmd = sprintf('"%s" -B -m unittest %s.%s.%s',...
          pythonPath,...
          'PyNWBIOTest', testCase.className(), testName);
      [status, cmdout] = system(cmd);
    end
  end
end