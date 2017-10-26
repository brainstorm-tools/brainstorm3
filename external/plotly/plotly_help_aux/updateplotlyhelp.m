%----UPDATE THE PLOTLY HELP GRAPH REFERENCE----%
function updateplotlyhelp

% remote Plotly Graph Reference url
remote = ['https://raw.githubusercontent.com/plotly/',...
    'graph_reference/master/graph_objs/matlab/graph_objs_keymeta.json'];

% download the remote content
try
    prContent = urlread(remote);
catch
    fprintf(['\nAn error occurred while trying to read the latest\n',...
        'Plotly MATLAB API graph reference from:\n',...
        'https://github.com/plotly/graph_reference.\n']);
    return
end

% load the json into a struct
pr = loadjson(prContent); 

%------------------------MATLAB SPECIFIC TWEAKS---------------------------%

%-key_type changes-%
pr.annotation.xref.key_type = 'plot_info'; 
pr.annotation.yref.key_type = 'plot_info'; 
pr.line.shape.key_type = 'plot_info'; 

%-------------------------------------------------------------------------%

% save directory
helpdir = fullfile(fileparts(which('updateplotlyhelp')),'plotly_reference'); 

% pr filename 
prname = fullfile(helpdir); 

%----save----%
save(prname,'pr'); 

end