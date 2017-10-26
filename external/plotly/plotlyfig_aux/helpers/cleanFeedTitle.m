function cleanFeedTitle(obj)
% cleanFeedTitle checks all annotations for a title. The first title found 
% is used as the layout.title (Plotly title). This should correspond to the 
% title of the first plot added to the MATLAB figure. cleanFeedTitle should
% be called after the style keys have been stripped --> it must override 
% certain style keys as a workaround.

% -- Single plot figure -- % 

% If only a single plot is present, the title will be set as the Plotly 
% title.

% -- Multiple plot figure -- % 

% If multiple plots are present, only the text of the title is used so 
% that the title appears in the feed. The text color is set so that the 
% Plotly title is hidden from the graph, favouring the 
% annotation title (with its flexibilty over positioning). 

    if ~isempty(obj.State.Figure.NumTexts)
        
        % grab the title of the first plot added to the figure. 
        first_title_index = find(arrayfun(@(x)(isequal(x.Title, 1)), ...
            obj.State.Text), 1, 'first');
        
        if ~isempty(first_title_index)
           
            first_title_handle = obj.State.Text(first_title_index).Handle; 
            
            % grab the string of the first title
            annotation_index = obj.getAnnotationIndex(first_title_handle); 
            first_title = obj.layout.annotations{annotation_index}.text;
            
            % use that as the filename
            obj.layout.title = first_title;

            % check for a single plot
            if (obj.State.Figure.NumPlots == 1)
                
                % grab the font style if not stripped
                if ~obj.PlotOptions.Strip
                    obj.layout.titlefont = ...
                        obj.layout.annotations{annotation_index}.font;
                end
                
                % remove the annotation 
                obj.layout.annotations(annotation_index) = [];
                obj.State.Figure.NumTexts = obj.State.Figure.NumTexts - 1;
                obj.State.Text(first_title_index) = []; 
                
                % adjust the top margin for the title
                obj.layout.margin.t = max(...
                    obj.PlotlyDefaults.MinTitleMargin,...
                    obj.layout.margin.t);   
            else
                
                % multiple plots ---> make the title invisible
                obj.layout.titlefont.color = 'rgba(0,0,0,0)';   
            end
        end
    end
end