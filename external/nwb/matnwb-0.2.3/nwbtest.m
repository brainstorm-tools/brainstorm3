function exitcode = nwbtest(varargin)
% NWBTEST Run MatNWB test suite.
%   
%   The nwbtest function provides a simple way to run the MatNWB test
%   suite. It writes a JUnit-style XML file containing the test results
%   (testResults.xml) and a Cobertura-style XML file containing a code
%   coverage report (coverage.xml).
%
%   EXITCODE = nwbtest() runs all tests in the MatNWB test suite and
%   returns a logical 1 (true) if any tests failed, or a logical 0 (false)
%   if all tests passed.
%
%   EXITCODE = nwbtest('Verbosity', VERBOSITY) runs the tests at the
%   specified VERBOSITY level. VERBOSITY can be specified as either a 
%   numeric value (1, 2, 3, or 4) or a value from the 
%   matlab.unittest.Verbosity enumeration.
%
%   EXITCODE = nwbtest(NAME, VALUE, ...) also supports those name-value 
%   pairs of the matlab.unittest.TestSuite.fromPackage function.
%
%   Examples:
%
%     % Run all tests in the MatNWB test suite.
%     nwbtests()
%
%     % Run all unit tests in the MatNWB test suite.
%     nwbtest('Name', 'tests.unit.*')
%
%     % Run only tests that match the ProcedureName 'testSmoke*'.
%     nwbtest('ProcedureName', 'testSmoke*')
%
%   See also: matlab.unittest.TestSuite.fromPackage
try
  import('matlab.unittest.TestSuite');
  import('matlab.unittest.TestRunner');
  import('matlab.unittest.plugins.XMLPlugin');
  
  parser = inputParser;
  parser.KeepUnmatched = true;
  parser.addParameter('Verbosity', 1);
  parser.parse(varargin{:});
  
  ws = getenv('WORKSPACE');
  if isempty(ws)
    ws = fileparts(mfilename('fullpath'));
  end
  
  pvcell = struct2pvcell(parser.Unmatched);
  suite = TestSuite.fromPackage('tests', 'IncludingSubpackages', true, pvcell{:});
  
  runner = TestRunner.withTextOutput('Verbosity', parser.Results.Verbosity);
  
  resultsFile = fullfile(ws, 'testResults.xml');
  runner.addPlugin(XMLPlugin.producingJUnitFormat(resultsFile));
  
  coverageFile = fullfile(ws, 'coverage.xml');
  mfilePaths = getMfilePaths(ws, {[mfilename '.m']}, {fullfile(ws, '+test')});
  addCoberturaCoverageIfPossible(runner, mfilePaths, coverageFile);
  
  results = runner.run(suite);
  
  display(results);
  exitcode = any([results.Failed]);
catch e
  disp(e.getReport('extended'));
  exitcode = 1;
end
end

function addCoberturaCoverageIfPossible(runner, files, coverageFile)
if ~verLessThan('matlab', '9.3')
  import('matlab.unittest.plugins.CodeCoveragePlugin');
  import('matlab.unittest.plugins.codecoverage.CoberturaFormat');
  
  runner.addPlugin(CodeCoveragePlugin.forFile(files, ...
    'Producing', CoberturaFormat(coverageFile)));
end
end

function pv = struct2pvcell(s)
p = fieldnames(s);
v = struct2cell(s);
n = 2*numel(p);

pv = cell(1,n);
pv(1:2:n) = p;
pv(2:2:n) = v;
end

function paths = getMfilePaths(folder, excludeNames, excludeFolders)
mfiles = dir(fullfile(folder, '**', '*.m'));
paths = {};
for i = 1:numel(mfiles)
  file = mfiles(i);
  if any(strcmp(file.name, excludeNames))
    continue;
  end
  if any(startsWith(file.folder, excludeFolders))
    continue;
  end
  paths{end+1} = fullfile(file.folder, file.name); %#ok<AGROW>
end
end