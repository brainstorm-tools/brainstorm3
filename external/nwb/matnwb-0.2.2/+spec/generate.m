function NamespaceInfo = generate(namespaceText, schemaSource)
%GENERATE Generates MATLAB classes from namespace mappings.
% optionally, include schema mapping as second argument OR path of specs
% schemaSource is either a path to a directory where the source is
% OR a containers.Map of filenames
Schema = spec.loadSchemaObject();
namespace = spec.schema2matlab(Schema.read(namespaceText));
NamespaceInfo = spec.getNamespaceInfo(namespace);
NamespaceInfo.namespace = namespace;
if ischar(schemaSource)
    schema = containers.Map;
    for i=1:length(NamespaceInfo.filenames)
        filenameStub = NamespaceInfo.filenames{i};
        filename = [filenameStub '.yaml'];
        fid = fopen(fullfile(schemaSource, filename));
        schema(filenameStub) = fread(fid, '*char') .';
        fclose(fid);
    end
    schema = spec.getSourceInfo(schema);
else % map of schemas with their locations
    schema = spec.getSourceInfo(schemaSource);
end

NamespaceInfo.schema = schema;
namespacePath = fullfile(misc.getWorkspace(), 'namespaces');
if 7 ~= exist(namespacePath, 'dir')
    mkdir(namespacePath);
end
cachePath = fullfile(namespacePath, [NamespaceInfo.name '.mat']);
save(cachePath, '-struct', 'NamespaceInfo');
end