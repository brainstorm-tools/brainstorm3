function Namespace = getNamespaceInfo(namespaceMap)
errid = 'MATNWB:INVALIDFILE';
errmsg = 'Could not read namespace file.  Invalid format.';

assert(isKey(namespaceMap, 'namespaces'), errid, errmsg);
namespaceMap = namespaceMap('namespaces');
namespaceMap = namespaceMap{1};
requiredKeysExist = isKey(namespaceMap, 'name')...
    && isKey(namespaceMap, 'schema')...
    && isKey(namespaceMap, 'version');
assert(requiredKeysExist, errid, errmsg);

name = namespaceMap('name');
version = namespaceMap('version');
schema = namespaceMap('schema');
Namespace = struct(...
    'name', misc.str2validName(name),...
    'filenames', {cell(size(schema))},...
    'dependencies', {cell(size(schema))},...
    'version', version);
for iSchemaSource=1:length(schema)
    schemaReference = schema{iSchemaSource};
    if isKey(schemaReference, 'source')
        sourceReference = schemaReference('source');
        if endsWith(sourceReference, '.yaml')
            [~, sourceReference, ~] = fileparts(sourceReference);
        end
        Namespace.filenames{iSchemaSource} = sourceReference;
    elseif isKey(schemaReference, 'namespace')
        Namespace.dependencies{iSchemaSource} = schemaReference('namespace');
    else
        error(errid, errmsg);
    end
end
emptyFileNamesMask = cellfun('isempty', Namespace.filenames);
Namespace.filenames(emptyFileNamesMask) = [];
emptyDependenciesMask = cellfun('isempty', Namespace.dependencies);
Namespace.dependencies(emptyDependenciesMask) = [];
end