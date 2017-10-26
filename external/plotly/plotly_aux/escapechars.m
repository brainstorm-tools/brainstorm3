function clean = escapechars(dirty)
    % escape \ and % chars for sprintf
    clean = strrep(dirty,'\', '\\');
    clean = strrep(clean,'%', '%%');
end
