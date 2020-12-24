function nwb = nwbRead(filename, varargin)
%NWBREAD Reads an NWB file.
%  nwb = nwbRead(filename) Reads the nwb file at filename and returns an
%  NWBFile object representing its contents.
%  nwb = nwbRead(filename, 'ignorecache') Reads the nwb file without generating classes
%  off of the cached schema if one exists.
%
%  Requires that core and extension NWB types have been generated
%  and reside in a 'types' package on the matlab path.
%
%  Example:
%    %Generate Matlab code for the NWB objects from the core schema.
%    %This only needs to be done once.
%    generateCore('schema\core\nwb.namespace.yaml');
%    %Now we can read nwb files!
%    nwb=nwbRead('data.nwb');
%
%  See also GENERATECORE, GENERATEEXTENSION, NWBFILE, NWBEXPORT
ignoreCache = ~isempty(varargin) && ischar(varargin{1}) &&...
    strcmp('ignorecache', varargin{1});
Blacklist = struct(...
    'attributes', {{'.specloc', 'object_id'}},...
    'groups', {{}});
validateattributes(filename, {'char', 'string'}, {'scalartext', 'nonempty'});

if ~ignoreCache
    specLocation = checkEmbeddedSpec(filename);
    if ~isempty(specLocation)
        Blacklist.groups{end+1} = specLocation;
    end
end

nwb = io.parseGroup(filename, h5info(filename), Blacklist);
end

function specLocation = checkEmbeddedSpec(filename)
specLocation = '';
try
    %check for .specloc
    fid = H5F.open(filename);
    attributeId = H5A.open(fid, '.specloc');
    referenceRawData = H5A.read(attributeId);
    specLocation = H5R.get_name(attributeId, 'H5R_OBJECT', referenceRawData);
    generateSpec(fid, h5info(filename, specLocation));
    rehash(); %required if we want parseGroup to read the right files.
    H5A.close(attributeId);
    H5F.close(fid);
catch ME
    if ~strcmp(ME.identifier, 'MATLAB:imagesci:hdf5lib:libraryError')
        rethrow(ME);
    end
    % attribute doesn't exist which is fine.
end
end

function generateSpec(fid, specinfo)
specNames = cell(size(specinfo.Groups));
for i=1:length(specinfo.Groups)
    location = specinfo.Groups(i).Groups(1);
    
    namespaceName = split(specinfo.Groups(i).Name, '/');
    namespaceName = namespaceName{end};
    
    filenames = {location.Datasets.Name};
    if ~any(strcmp('namespace', filenames))
        warning('NWB:Read:GenerateSpec:CacheInvalid',...
        'Couldn''t find a `namespace` in namespace `%s`.  Skipping cache generation.',...
        namespaceName);
        return;
    end
    sourceNames = {location.Datasets.Name};
    fileLocation = strcat(location.Name, '/', sourceNames);
    schemaMap = containers.Map;
    for j=1:length(fileLocation)
        did = H5D.open(fid, fileLocation{j});
        if strcmp('namespace', sourceNames{j})
            namespaceText = H5D.read(did);
        else
            schemaMap(sourceNames{j}) = H5D.read(did);    
        end
        H5D.close(did);
    end
    
    Namespace = spec.generate(namespaceText, schemaMap);
    specNames{i} = Namespace.name;
end

missingNames = cell(size(specNames));
for i = 1:length(specNames)
    name = specNames{i};
    if ~tryWriteSpec(name)
        missingNames{i} = name;
    end
end
missingNames(cellfun('isempty', missingNames)) = [];
assert(isempty(missingNames), 'Nwb:Namespace:DependencyMissing',...
    'Missing generated caches and dependent caches for the following namespaces:\n%s',...
            misc.cellPrettyPrint(missingNames));
end

function writeSuccessful = tryWriteSpec(namespaceName)
try
    file.writeNamespace(namespaceName);
    writeSuccessful = true;
catch ME
    if ~strcmp(ME.identifier, 'Nwb:Namespace:CacheMissing')
        rethrow(ME);
    end
    writeSuccessful = false;
end
end
