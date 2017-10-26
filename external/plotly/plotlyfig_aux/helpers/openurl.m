function openurl(url)
try
    desktop = com.mathworks.mde.desk.MLDesktop.getInstance;
    editor = desktop.getGroupContainer('Editor');
    if(~isempty(url) && ~isempty(editor));
        fprintf(['\nLet''s have a look: <a href="matlab:web(''%s'', ''-browser'');">' url '</a>\n\n'], url)
    end
end
end