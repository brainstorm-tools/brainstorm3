function removed = plotlycleanup

% cleans up any old Plotly API MATLAB library files and folders

% initialize output
removed = {};

%----REMOVE WRAPPER FILES----%
REMOVEFILES = {'plotly.m'};

%----REMOVE WRAPPER FOLDERS----%
REMOVEFOLDERS = {'fig2plotly_aux'};

%----check for local Plotly instances----%
try
    plotlyScriptDirs = which('plotly.m','-all');
    
    if isempty(plotlyScriptDirs);
        error('plotly:missingScript',...
            ['\n\nWe were unable to locate plotly.m. Please Add this\n',...
            'script to your MATLAB search path and try again.\n\n']);
    end
     
catch exception %locating plotly error catch...
    fprintf(['\n\n' exception.identifier exception.message '\n\n']);
    return
end

% plotly toolbox directory
plotlyToolboxDir = fullfile(matlabroot,'toolbox','plotly');

% find the location of all plotly/ directories
dircount = 1; 
for d = 1:length(plotlyScriptDirs)
    %parse filepath string at the Plotly directory
    plotlyLoc = strfind(fileparts(plotlyScriptDirs{d}),fullfile('MATLAB-api-master','plotly'));
    plotlyToolboxLoc = strfind(fileparts(plotlyScriptDirs{d}),plotlyToolboxDir); 
    if ~isempty(plotlyLoc)
        plotlyDirs{dircount} = fullfile(plotlyScriptDirs{d}(1:plotlyLoc-1),'MATLAB-api-master','plotly');
        dircount = dircount + 1; 
    elseif ~isempty(plotlyToolboxLoc)
        plotlyDirs{dircount} = plotlyToolboxDir;
        dircount = dircount + 1; 
    end
end

for d = 1:length(plotlyDirs)
    
    % add plotlydirs to searchpath (will be removed in future once handled by plotlyupdate)
    addpath(genpath(plotlyDirs{d}));
    
    % delete files from plotly directory
    removefiles = fullfile(plotlyDirs{d}, REMOVEFILES);
    
    for f = 1:length(removefiles)
        
        % remove removefiles filepath from searchpath
        rmpath(fileparts(removefiles{f}));
        
        if exist(removefiles{f},'file')
            delete(removefiles{f});
            % update removed list
            removed = [removed removefiles{f}];
        end
        
        % add removefiles filepath back to searchpath
        addpath(fileparts(removefiles{f}));
        
    end

    % remove folders from plotly directory
    removefolders = fullfile(plotlyDirs{d},REMOVEFOLDERS);
    
    for f = 1:length(removefolders)
        if exist(removefolders{f},'dir')
            
            %remove folder from path
            rmpath(genpath(removefolders{f}));
            
            %delete folder/subfolders
            try
                status = rmdir(removefolders{f},'s');

                if (status == 0)
                    error('plotly:deletePlotlyAPI',...
                        ['\n\nShoot! It looks like something went wrong removing the Plotly API ' ...
                        'from the MATLAB toolbox directory \n' ...
                        'Please contact your system admin. or chuck@plot.ly for more information. \n\n']);
                end
                
                % update removed list
                removed = [removed removefolders{f}];
 
            end
        end
    end   
end
end