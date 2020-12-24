function generateCore(varargin)
% GENERATECORE Generate Matlab classes from NWB core schema files
%   GENERATECORE()  Generate classes (Matlab m-files) from the
%   NWB:N core namespace file.
%
%   GENERATECORE(core_or_extension_paths,...)  Generate classes for the
%   core namespace as well as one or more extenstions.  Each input filename
%   should be an NWB namespace file.
%
%   A cache of schema data is generated in the 'namespaces' subdirectory in
%   the current working directory.  This is for allowing cross-referencing
%   classes between multiple namespaces.
%
%   Output files are generated placed in a '+types' subdirectory in the
%   current working directory.
%
%   Example:
%      generateCore();
%      generateCore('schema/core/nwb.namespace.yaml');
%      generateCore('schema/my_ext/myext.namespace.yaml');
%
%   See also GENERATEEXTENSION
if nargin == 0
    [nwbLocation, ~, ~] = fileparts(mfilename('fullpath'));
    schemaPath = fullfile(nwbLocation, 'nwb-schema');
    corePath = fullfile(schemaPath, 'core', 'nwb.namespace.yaml');
    commonPath = fullfile(schemaPath, 'hdmf-common-schema', ...
        'common', 'namespace.yaml');
    
    if 2 == exist(commonPath, 'file')
        generateExtension(commonPath);
    end
    
    generateExtension(corePath);
else
    for i=1:length(varargin)
        generateExtension(varargin{i});
    end
end
end