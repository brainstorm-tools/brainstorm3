function parsed = parseGroup(filename, info, Blacklist)
% NOTE, group name is in path format so we need to parse that out.
% parsed is either a containers.Map containing properties mapped to values OR a
% typed value
if nargin < 3
    Blacklist = struct(...
        'attributes', {{'.specloc', 'object_id'}},...
        'groups', {{}});
end

links = containers.Map;
refs = containers.Map;
[~, root] = io.pathParts(info.Name);
[attributeProperties, Type] =...
    io.parseAttributes(filename, info.Attributes, info.Name, Blacklist);

%parse datasets
datasetProperties = containers.Map;
for i=1:length(info.Datasets)
    datasetInfo = info.Datasets(i);
    fullPath = [info.Name '/' datasetInfo.Name];
    dataset = io.parseDataset(filename, datasetInfo, fullPath, Blacklist);
    if isa(dataset, 'containers.Map')
        datasetProperties = [datasetProperties; dataset];
    else
        datasetProperties(datasetInfo.Name) = dataset;
    end
end

%parse subgroups
groupProperties = containers.Map;
for i=1:length(info.Groups)
    group = info.Groups(i);
    if any(strcmp(group.Name, Blacklist.groups))
        continue;
    end
    [~, gname] = io.pathParts(group.Name);
    subg = io.parseGroup(filename, group, Blacklist);
    groupProperties(gname) = subg;
end

%create link stub
linkProperties = containers.Map;
for i=1:length(info.Links)
    link = info.Links(i);
    switch link.Type
        case 'soft link'
            lnk = types.untyped.SoftLink(link.Value{1});
        otherwise %todo assuming external link here
            lnk = types.untyped.ExternalLink(link.Value{:});
    end
    linkProperties(link.Name) = lnk;
end

if isempty(Type.typename)
    parsed = types.untyped.Set(...
        [attributeProperties; datasetProperties; groupProperties; linkProperties]);
    
    if isempty(parsed)
        %special case where a directory is simply empty.  Return itself but
        %empty
        parsed(root) = [];
    end
else
    if groupProperties.Count > 0
        %elide group properties
        elided_gprops = elide(groupProperties, properties(Type.typename));
        groupProperties = [groupProperties; elided_gprops];
    end
    %construct as kwargs and instantiate object
    kwargs = io.map2kwargs(...
        [attributeProperties; datasetProperties; groupProperties; linkProperties]);
    if isempty(root)
        %we are root
        if strcmp(Type.name, 'NWBFile')
            parsed = NwbFile(kwargs{:});
        else
            file.cloneNwbFileClass(Type.name, Type.typename);
            rehash();
            parsed = eval([Type.typename '(kwargs{:})']);
        end
        
        return;
    end
    parsed = eval([Type.typename '(kwargs{:})']);
end
end

%NOTE: SIDE EFFECTS ALTER THE SET
function elided = elide(set, prop, prefix)
%given raw data representation, match to closest property.
% return a typemap of matching typeprops and their prop values to turn into kwargs
% depth first search through the set to construct a possible type prop
if nargin < 3
    prefix = '';
end
elided = containers.Map;
elidekeys = keys(set);
elidevals = values(set);
drop = false(size(elidekeys));
if ~isempty(prefix)
    potentials = strcat(prefix, '_', elidekeys);
else
    potentials = elidekeys;
end
for i=1:length(potentials)
    pvar = potentials{i};
    pvalue = elidevals{i};
    if isa(pvalue, 'containers.Map') || isa(pvalue, 'types.untyped.Set')
        if pvalue.Count == 0
            drop(i) = true;
            continue; %delete
        end
        leads = startsWith(prop, pvar);
        if any(leads)
            %since set has been edited, we bubble up deletion of the old keys.
            subset = elide(pvalue, prop(leads), pvar);
            elided = [elided; subset];
            if pvalue.Count == 0
                drop(i) = true;
            elseif any(strcmp(pvar, prop))
                elided(pvar) = pvalue;
                drop(i) = true;
            else
                warning('Unable to match property `%s` under prefix `%s`',...
                    pvar, prefix);
            end
        end
    elseif any(strcmp(pvar, prop))
        elided(pvar) = pvalue;
        drop(i) = true;
    end
end
remove(set, elidekeys(drop)); %delete all leftovers that were yielded
end