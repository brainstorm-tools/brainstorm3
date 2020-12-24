function JsonData = exportJson()
%TOJSON loads and converts loaded namespaces to json strings
%   returns containers.map of namespace names.
namespaceDir = fullfile(misc.getWorkspace(), 'namespaces');
namespaceList = dir(namespaceDir);
isFileMask = ~[namespaceList.isdir];
namespaceFiles = namespaceList(isFileMask);
namespaceNames = {namespaceFiles.name};
for iFile = 1:length(namespaceNames)
    [~, namespaceNames{iFile}, ~] = fileparts(namespaceNames{iFile});
end


Caches = schemes.loadCache(namespaceNames{:});
JsonData = struct(...
    'name', namespaceNames,...
    'version', repmat({''}, size(Caches)),...
    'json', repmat({containers.Map.empty}, size(Caches)));
for iCache = 1:length(Caches)
    Cache = Caches(iCache);
    stripNamespaceFileExt(Cache.namespace);
    JsonMap = containers.Map({'namespace'}, {jsonencode(Cache.namespace)});
    for iScheme = 1:length(Cache.filenames)
        filename = Cache.filenames{iScheme};
        JsonMap(filename) = jsonencode(Cache.schema(filename));
    end
    
    JsonData(iCache).version = Cache.version;
    JsonData(iCache).json = JsonMap;
end
end

function NamespaceRoot = stripNamespaceFileExt(NamespaceRoot)
Namespace = NamespaceRoot('namespaces');
Namespace = Namespace{1};
Schema = Namespace('schema');
for iScheme = 1:length(Schema)
    Scheme = Schema{iScheme};
    if ~Scheme.isKey('source')
        continue;
    end
    source = Scheme('source');
        
    if endsWith(source, '.yaml')
        [~, Scheme('source'), ~] = fileparts(source);
    end
end
end