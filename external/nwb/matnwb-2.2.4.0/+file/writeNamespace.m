function writeNamespace(namespaceName)
%check/load dependency namespaces
Namespace = schemes.loadNamespace(namespaceName);

path = fullfile(misc.getWorkspace(), '+types', ['+' Namespace.name]);
if exist(path, 'dir') == 7
    rmdir(path, 's');
end
mkdir(path);
classes = keys(Namespace.registry);
pregenerated = containers.Map; %generated nodes and props for faster dependency resolution
for i=1:length(classes)
    className = classes{i};
    [processed, classprops, inherited] = file.processClass(className, Namespace, pregenerated);
    
    if isempty(processed)
        continue;
    end
    
    fid = fopen(fullfile(path, [className '.m']), 'W');
    try
        fwrite(fid, file.fillClass(className, Namespace, processed, ...
            classprops, inherited), 'char');
    catch ME
        fclose(fid);
        rethrow(ME)
    end
    fclose(fid);
end
end