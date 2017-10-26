function p = getplotlyfig(file_owner, file_id)

%-----------------------------SAVEPLOTLYFIG-------------------------------%
% Grab an online Plotly figure's data/layout information
% [CALL]:
% p = getplotlyfig(file_owner file_id)
% [INPUTS]: [TYPE]{default} - description/'options'
% file_owner: [string]{} - Unique Plotly username
% file_id [int]{} - the id of the graph you want to obtain
% [OUTPUT]:
% p - plotlyfig object
% [EXAMPLE]:
% url: https://plot.ly/~demos/1526
% fig = getplotlyfig('demos','1526'); 
% [ADDITIONAL RESOURCES]:
% For full documentation and examples, see https://plot.ly/matlab/get-requests/
%-------------------------------------------------------------------------%

%--CONSTRUCT PLOTLY FIGURE OBJECT--%
p = plotlyfig('Visible','off');

%-------------------------------------------------------------------------%

%--MAKE CALL TO DOWNLOAD METHOD--%
p.download(file_owner, file_id);

%-------------------------------------------------------------------------%

end
