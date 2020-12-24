function [args, typename] = parseAttributes(filename, attributes, context, Blacklist)
%typename is the type of name if it exists.  Empty string otherwise
%args is a containers.Map of all valid attributes
args = containers.Map;
typename = '';
type = struct('namespace', '', 'name', '');
if isempty(attributes)
    return;
end
names = {attributes.Name};

typeDefMask = strcmp(names, 'neurodata_type');
hasTypeDef = any(typeDefMask);
if hasTypeDef
    typeDef = attributes(typeDefMask).Value;
    if iscellstr(typeDef)
        typeDef = typeDef{1};
    end
    type.name = typeDef;
end

namespaceMask = strcmp(names, 'namespace');
hasNamespace = any(namespaceMask);
if hasNamespace
    namespace = attributes(namespaceMask).Value;
    if iscellstr(namespace)
        namespace = namespace{1};
    end
    type.namespace = namespace;
end

if hasTypeDef && hasNamespace
    validNamespace = misc.str2validName(type.namespace);
    validName = misc.str2validName(type.name);
    typename = ['types.' validNamespace '.' validName];
end

blacklistMask = ismember(names, Blacklist.attributes);
deleteMask = typeDefMask | namespaceMask | blacklistMask;
attributes(deleteMask) = [];
for i=1:length(attributes)
    attr = attributes(i);
    if strcmp(attr.Datatype.Class, 'H5T_REFERENCE')
        fid = H5F.open(filename, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
        aid = H5A.open_by_name(fid, context, attr.Name);
        tid = H5A.get_type(aid);
        args(attr.Name) = io.parseReference(aid, tid, attr.Value);
        H5T.close(tid);
        H5A.close(aid);
        H5F.close(fid);
    elseif isscalar(attr.Value) && iscellstr(attr.Value)
        args(attr.Name) = attr.Value{1};
    else
        args(attr.Name) = attr.Value;
    end
end
end
