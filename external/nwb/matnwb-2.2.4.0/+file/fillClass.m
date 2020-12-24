function template = fillClass(name, namespace, processed, classprops, inherited)
%name is the name of the scheme
%namespace is the namespace context for this class

%% PROCESSING
class = processed(1);

allprops = keys(classprops);
required = {};
optional = {};
readonly = {};
defaults = {};
dependent = {};
%separate into readonly, required, and optional properties
for i=1:length(allprops)
    pnm = allprops{i};
    prop = classprops(pnm);
    
    if ischar(prop) || isa(prop, 'containers.Map') || isstruct(prop) || prop.required
        required = [required {pnm}];
    else
        optional = [optional {pnm}];
    end
    
    if isa(prop, 'file.Attribute')
        if prop.readonly
            readonly = [readonly {pnm}];
        end
        
        if ~isempty(prop.value)
            defaults = [defaults {pnm}];
        end
       
        if ~isempty(prop.dependent)
            %extract prefix
            parentName = strrep(pnm, ['_' prop.name], '');
            parent = classprops(parentName);
            if ~parent.required
                dependent = [dependent {pnm}];
            end
        end
    end
end
nonInherited = setdiff(allprops, inherited);
readonly = intersect(readonly, nonInherited);
required = intersect(required, nonInherited);
optional = intersect(optional, nonInherited);

%% CLASSDEF
if length(processed) <= 1
    depnm = 'types.untyped.MetaClass'; %WRITE
else
    parentName = processed(2).type; %WRITE
    depnm = namespace.getFullClassName(parentName);
end

if isa(processed, 'file.Group')
    classTag = 'types.untyped.GroupClass';
else
    classTag = 'types.untyped.DatasetClass';
end

%% return classfile string
classDef = [...
    'classdef ' name ' < ' depnm ' & ' classTag newline... %header, dependencies
    '% ' upper(name) ' ' class.doc]; %name, docstr
propgroups = {...
    @()file.fillProps(classprops, readonly, 'SetAccess=protected')...
    @()file.fillProps(classprops, setdiff([required optional], readonly))...
    };
docsep = {...
    '% READONLY'...
    '% PROPERTIES'...
    };
propsDef = '';
for i=1:length(propgroups)
    pg = propgroups{i};
    pdef = pg();
    if ~isempty(pdef)
        propsDef = strjoin({propsDef docsep{i} pdef}, newline);
    end
end

constructorBody = file.fillConstructor(...
    name,...
    depnm,...
    defaults,... %all defaults, regardless of inheritance
    [required optional],...
    classprops,...
    namespace);
setterFcns = file.fillSetters(setdiff(nonInherited, readonly));
validatorFcns = file.fillValidators(allprops, classprops, namespace);
exporterFcns = file.fillExport(nonInherited, class, depnm);
methodBody = strjoin({constructorBody...
    '%% SETTERS' setterFcns...
    '%% VALIDATORS' validatorFcns...
    '%% EXPORT' exporterFcns}, newline);
fullMethodBody = strjoin({'methods' ...
    file.addSpaces(methodBody, 4) 'end'}, newline);
template = strjoin({classDef propsDef fullMethodBody 'end'}, ...
    [newline newline]);
end

