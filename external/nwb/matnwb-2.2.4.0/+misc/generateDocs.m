function generateDocs()
% GENERATEDOCS generates docs for MatNWB user API
%   GENERATEDOCS() generate documentation for MATLAB files in the current working directory.
%
%   Requires <a href="matlab:
%   web('https://www.artefact.tk/software/matlab/m2html/')">m2html</a> in your path.
rootFiles = dir('.');
rootFiles = {rootFiles.name};
rootWhitelist = {'generateCore.m', 'generateExtension.m', 'nwbRead.m', 'nwbExport.m'};
isWhitelisted = ismember(rootFiles, rootWhitelist);
rootFiles(~isWhitelisted) = [];

m2html('mfiles', rootFiles, 'htmldir', 'doc');

% correct html files in root directory as the stylesheets will be broken
fprintf('Correcting files in root directory...\n');
rootFiles = dir('doc');
rootFiles = {rootFiles.name};
htmlMatches = regexp(rootFiles, '\.html$', 'once');
isHtmlFile = ~cellfun('isempty', htmlMatches);
rootFiles(~isHtmlFile) = [];
rootFiles = fullfile('doc', rootFiles);

for iDoc=1:length(rootFiles)
    fileName = rootFiles{iDoc};
    fprintf('Processing %s...\n', fileName);
    fileReplace(fileName, '\.\.\/', '');
end

% correct index.html so the header indicates MatNWB
fprintf('Correcting index.html Header...\n');
indexPath = fullfile('doc', 'index.html');
fileReplace(indexPath, 'Index for \.', 'Index for MatNWB');

% remove directories listing in index.html
fprintf('Removing index.html directories listing...\n');
matchPattern = ['<h2>Subsequent directories:</h2>\r?\n'...
    '<ul style="list-style-image:url\(matlabicon\.gif\)">\r?\n'...
    '(:?<li>.+</li>)+</ul>'];
fileReplace(indexPath, matchPattern, '');
end

function fileReplace(fileName, regexPattern, replacement)
file = fopen(fileName, 'r');
fileText = fread(file, '*char') .';
fclose(file);
fileText = regexprep(fileText, regexPattern, replacement);
file = fopen(fileName, 'W');
fwrite(file, fileText);
fclose(file);
end