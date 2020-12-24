% get type declarations from scheme
% a scheme object is a containers.Map representing a specific file in the Namespace
% classes is a map containing groups or datasets which in turn are cell arrays
% of the Java HashMaps which hold the class definition.
% nargin specifies by name which classes to list by name
function Classes = getClasses(scheme, varargin)
Classes = containers.Map;

if isKey(scheme, 'datasets')
     Classes = [Classes; searchForClasses('datasets', scheme('datasets'), varargin)];
end

if isKey(scheme, 'groups')
    Classes = [Classes; searchForClasses('groups', scheme('groups'), varargin)];
    groups = scheme('groups');
    for iGroup=1:length(groups)
        groupMap = groups{iGroup};
        if isKey(groupMap, 'groups') || isKey(groupMap, 'datasets')
            Classes = [Classes; schemes.getClasses(groupMap, varargin{:})];
        end
    end
end
end

function classMap = searchForClasses(type, list, whitelist)
allowedTypeDefNames = {'neurodata_type_def', 'data_type_def'};
classMap = containers.Map;
shouldSkipWhitelist = isempty(whitelist);
for iObj=1:length(list)
    dataObject = list{iObj};
    hasTypeDef = isKey(dataObject, allowedTypeDefNames);
    if any(hasTypeDef)
        typeDef = dataObject(allowedTypeDefNames{hasTypeDef});
        if shouldSkipWhitelist || ismember(typeDef, whitelist)
            dataObject('class_type') = type;
            classMap(typeDef) = dataObject;
        end
    end
end
end