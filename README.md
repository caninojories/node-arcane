#Intallation:

  source <(wget -qO- http://tinyurl.com/zhn4k6l)
  
###Add a New Project:
  
  arce new-project [Project Name]
  
###Add the Project to VHost:
  
  arce vhost -add [HTTP URL]
  
  ex: 
    arce vhost -add 'localhost/my-project'
  
###Remove the Project in VHost
  
  arce vhost -remove [HTTP URL]
  
  ex:
    arce vhost -remove 'localhost/my-project'
    
###Running Arcane:
  
  arce run
  
###Tracing Arcane:
  
  arce trace

