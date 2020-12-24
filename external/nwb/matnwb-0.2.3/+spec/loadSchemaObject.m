function schema = loadSchemaObject()
%LOADSCHEMAOBJECT Loads YAML reader from jar
%   Returns a Java object which can read() yaml text
try
    schema = Schema();
catch
    nwb_loc = fileparts(which('NwbFile'));
    java_loc = fullfile(nwb_loc, 'jar', 'schema.jar');
    javaaddpath(java_loc);
    schema = Schema();
end
end