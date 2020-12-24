function processed = getSourceInfo(classMap)
%given containers.Map of (file/module)->(string) returns (file/module)->HashMap
% representing the schema file.
processed = containers.Map;
schema = Schema();
classNames = keys(classMap);

for i=1:length(classNames)
    name = classNames{i};
    schemaText = classMap(name);
    try
        processed(name) = spec.schema2matlab(schema.read(schemaText));
    catch ME
        error('MATNWB:INVALIDFILE',...
            'Data for namespace source `%s` is invalid', name);
    end
end
