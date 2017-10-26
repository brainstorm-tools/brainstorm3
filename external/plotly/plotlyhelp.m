function plotlyref = plotlyhelp(varargin)
% [EX]: plotlyhelp('scatter','fill');

%converts graph_obj_meta.json to struct/cell array and outputs key
plotlyref = load('plotly_reference.mat');
pr = plotlyref.pr; 
pr.online = 'Access the online docs!';

try
    switch length(varargin)
        case 0
            plotlyref = pr;
        case 1
            if(strcmpi('online',varargin{1}));
                web('http://plot.ly/matlab/','-browser')
            else
                plotlyref = pr.(lower(varargin{1}));
            end
        case 2
            plotlyref = pr.(lower(varargin{1})).(lower(varargin{2}));
        case 3 
            plotlyref = pr.(lower(varargin{1})).(lower(varargin{2})).(lower(varargin{3}));
        case 4 %does the struct nesting ever go beyond 4?
            plotlyref = pr.(lower(varargin{1})).(lower(varargin{2})).(lower(varargin{3})).(lower(varargin{4}));
    end
    
catch exception
    fprintf('\n\nSorry! We could not find what you were looking for. Please specify a valid Plotly reference.\n\n');
end

end
