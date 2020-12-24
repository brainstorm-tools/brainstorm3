function festr = fillExport(propnames, raw, parentName)
hdrstr = 'function refs = export(obj, fid, fullpath, refs)';
if isa(raw, 'file.Dataset')
    propnames = propnames(~strcmp(propnames, 'data'));
end

bodystr = {strjoin({...
    ['refs = export@' parentName '(obj, fid, fullpath, refs);']...
    'if any(strcmp(refs, fullpath))'...
    '    return;'...
    'end'...
    }, newline)};

if isa(raw, 'file.Group') && strcmp(raw.type, 'NWBFile')
    %NWBFile is technically the root `group`, which in HDF5 is a single `/`
    % this messes with property creation so we reassign the path here to
    % empty string so concatenation looks right
    bodystr = [bodystr {'fullpath = '''';'}];
end

for i = 1:length(propnames)
    pnm = propnames{i};
    pathProps = traverseRaw(pnm, raw);
    prop = pathProps{end};
    elideProps = pathProps(1:end-1);
    
    %Construct elisions
    elisions = cell(length(elideProps),1);
    for j = 1:length(elideProps)
        elisions{j} = elideProps{j}.name;
    end
    
    elisions = strjoin(elisions, '/');
    if ~isempty(elideProps) && all(cellfun('isclass', elideProps, 'file.Group'))
        bodystr{end+1} = ['io.writeGroup(fid, [fullpath ''/' elisions ''']);'];
    end
    bodystr{end+1} = fillDataExport(pnm, prop, elisions);
end

festr = strjoin({hdrstr...
    file.addSpaces(strjoin(bodystr, newline), 4)...
    'end'}, newline);
end

function path = traverseRaw(propname, raw)
path = {};
switch class(raw)
    case 'file.Group'
        %get names of both subgroups and datasets
        gnames = {};
        dsnames = {};
        lnknames = {};
        anames = {};
        
        if ~isempty(raw.attributes)
            anames = {raw.attributes.name};
        end
        
        if ~isempty(raw.subgroups)
            gnames = {raw.subgroups.name};
            lowerGroupTypes = lower({raw.subgroups.type});
            useLower = [raw.subgroups.isConstrainedSet] | cellfun('isempty', gnames);
            gnames(useLower) = lowerGroupTypes(useLower);
        end
        
        if ~isempty(raw.datasets)
            dsnames = {raw.datasets.name};
            lowerDsTypes = lower({raw.datasets.type});
            useLower = [raw.datasets.isConstrainedSet];
            dsnames(useLower) = lowerDsTypes(useLower);
        end
        
        if ~isempty(raw.links)
            lnknames = {raw.links.name};
        end
        
        if any(strcmp([anames gnames dsnames lnknames], propname))
            amatch = strcmp(anames, propname);
            gmatch = strcmp(gnames, propname);
            dsmatch = strcmp(dsnames, propname);
            lnkmatch = strcmp(lnknames, propname);
            if any(amatch)
                path = {raw.attributes(amatch)};
            elseif any(gmatch)
                path = {raw.subgroups(gmatch)};
            elseif any(dsmatch)
                path = {raw.datasets(dsmatch)};
            elseif any(lnkmatch)
                path = {raw.links(lnkmatch)};
            end
            return;
        end
        
        %find true path for elided property
        if startsWith(propname, dsnames) || startsWith(propname, gnames)
            for i=1:length(gnames)
                nm = gnames{i};
                suffix = propname(length(nm)+2:end);
                if startsWith(propname, nm)
                    res = traverseRaw(suffix, raw.subgroups(i));
                    if ~isempty(res)
                        path = [{raw.subgroups(i)} res];
                        return;
                    end
                end
            end
            for i=1:length(dsnames)
                nm = dsnames{i};
                suffix = propname(length(nm)+2:end);
                if startsWith(propname, nm)
                    res = traverseRaw(suffix, raw.datasets(i));
                    if ~isempty(res)
                        path = [{raw.datasets(i)} res];
                        return;
                    end
                end
            end
        end
    case 'file.Dataset'
        attrmatch = strcmp({raw.attributes.name}, propname);
        if any(attrmatch)
            path = {raw.attributes(attrmatch)};
        end
end
end

function fde = fillDataExport(name, prop, elisions)
if isempty(elisions)
    fullpath = ['[fullpath ''/' prop.name ''']'];
    elisionpath = 'fullpath';
else
    fullpath = ['[fullpath ''/' elisions '/' prop.name ''']'];
    elisionpath = ['[fullpath ''/' elisions ''']'];
end

if (isa(prop, 'file.Group') || isa(prop, 'file.Dataset')) && prop.isConstrainedSet
    fde = ['refs = obj.' name '.export(fid, ' elisionpath ', refs);'];
elseif isa(prop, 'file.Link') || isa(prop, 'file.Group') ||...
        (isa(prop, 'file.Dataset') && ~isempty(prop.type))
    % obj, loc_id, path, refs
    fde = ['refs = obj.' name '.export(fid, ' fullpath ', refs);'];
elseif isa(prop, 'file.Dataset') %untyped dataset
    options = {};
    if ~prop.scalar
        options = [options {'''forceArray'''}];
    end
    
    % special case due to unique behavior of file_create_date
    if strcmp(name, 'file_create_date')
        options = [options {'''forceChunking'''}];
    end
    % just to guarantee optional arguments are correct syntax
    nameProp = sprintf('obj.%s', name);
    nameArgs = [{nameProp} options];
    nameArgs = strjoin(nameArgs, ', ');
    fde = strjoin({...
        ['if startsWith(class(obj.' name '), ''types.untyped.'')']...
        ['    refs = obj.' name '.export(fid, ' fullpath ', refs);']...
        ['elseif ~isempty(obj.' name ')']...
        ['    ' sprintf('io.writeDataset(fid, %1$s, %2$s);',...
            fullpath, nameArgs)]...
        'end'...
        }, newline);
else
    if prop.scalar
        forceArrayFlag = '';
    else
        forceArrayFlag = ', ''forceArray''';
    end
    fde = sprintf('io.writeAttribute(fid, %1$s, obj.%2$s%3$s);',...
        fullpath, name, forceArrayFlag);
end

emptycheck = ['if ~isempty(obj.' name ')'];

if isa(prop, 'file.Attribute') && ~isempty(prop.dependent)
    %if attribute is dependent, check before writing
    if isempty(elisions) || strcmp(elisions, prop.dependent)
        depPropname = prop.dependent;
    else
        flattened = strfind(elisions, '/');
        flattened = strrep(elisions(1:flattened(end)), '/', '_');
        depPropname = [flattened prop.dependent];
    end
    emptycheck = [emptycheck ' && ~isempty(obj.' depPropname ')'];
end

fde = [emptycheck newline file.addSpaces(fde, 4)];

if prop.required
    errmsg = ['    error(''Property `' name '` is required in `%s`.'', fullpath);'];
    if isa(prop, 'file.Attribute') && ~isempty(prop.dependent)
        errmsg = ['elseif ~isempty(obj.' depPropname ')' newline errmsg];
    else
        errmsg = ['else' newline errmsg];
    end
    fde = [fde newline errmsg];
end

fde = [fde newline 'end'];

end