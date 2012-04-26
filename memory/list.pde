

/* this initialises a node, allocates memory for the node, and returns   */
/* a pointer to the newNode node. Must pass it the node details, name and id */
struct node * initnode( char *id, int value,prog_char *type )
{
   struct node *ptr;
   ptr = (struct node *) calloc( 1, sizeof(struct node ) );
   if( ptr == NULL )                       /* error allocating node?      */
       return (struct node *) NULL;        /* then return NULL, else      */
   else {                                  /* allocated node successfully */
       strcpy( ptr->id, id );          /* fill in name details        */
       ptr->value = value; 
       ptr->type = type;       /* copy id details             */
       return ptr;                         /* return pointer to newNode node  */
   }
}

/* this prints the details of a node, eg, the name and id                 */
/* must pass it the address of the node you want to print out             */
void printnode( struct node *ptr )
{
   Serial.println( ptr->id );
   Serial.println( ptr->value );
}

/* this prints all nodes from the current address passed to it. If you    */
/* pass it 'head', then it prints out the entire list, by cycling through */
/* each node and calling 'printnode' to print each node found             */
void printlist( struct node *ptr )
{
   while( ptr != NULL )           /* continue whilst there are nodes left */
   {
      printnode( ptr );           /* print out the current node           */
      ptr = ptr->next;            /* goto the next node in the list       */
   }
}

/* this adds a node to the end of the list. You must allocate a node and  */
/* then pass its address to this function                                 */
void add( struct node *newNode )  /* adding to end of list */
{
   if( head == NULL )      /* if there are no nodes in list, then         */
       head = newNode;         /* set head to this newNode node                   */
   end->next = newNode;        /* link in the newNode node to the end of the list */
   newNode->next = NULL;       /* set next field to signify the end of list   */
   end = newNode;              /* adjust end to point to the last node        */
}

/* search the list for a name, and return a pointer to the found node     */
/* accepts a name to search for, and a pointer from which to start. If    */
/* you pass the pointer as 'head', it searches from the start of the list */
struct node * searchname( struct node *ptr, char *id )
{
    while( strcmp( id, ptr->id ) != 0 ) {    /* whilst name not found */
       ptr = ptr->next;                          /* goto the next node    */
       if( ptr == NULL )                         /* stop if we are at the */
          break;                                 /* of the list           */
    }
    return ptr;                                  /* return a pointer to   */
}                                                /* found node or NULL    */

/* deletes the specified node pointed to by 'ptr' from the list           */
void deletenode( struct node *ptr )
{
   struct node *temp, *prev;
   temp = ptr;    /* node to be deleted */
   prev = head;   /* start of the list, will cycle to node before temp    */

   if( temp == prev ) {                    /* are we deleting first node  */
       head = head->next;                  /* moves head to next node     */
       if( end == temp )                   /* is it end, only one node?   */
          end = end->next;                 /* adjust end as well          */
       free( temp );                       /* free space occupied by node */
   }
   else {                                  /* if not the first node, then */
       while( prev->next != temp ) {       /* move prev to the node before*/
           prev = prev->next;              /* the one to be deleted       */
       }
       prev->next = temp->next;            /* link previous node to next  */
       if( end == temp )                   /* if this was the end node,   */
           end = prev;                     /* then reset the end pointer  */
       free( temp );                       /* free space occupied by node */
   }
}

/* inserts a newNode node, uses name field to align node as alphabetical list */
/* pass it the address of the newNode node to be inserted, with details all   */
/* filled in                                                              */
void insertnode( struct node *newNode )
{
   struct node *temp, *prev;                /* similar to deletenode      */

   if( head == NULL ) {                     /* if an empty list,          */
       head = newNode;                          /* set 'head' to it           */
       end = newNode;
       head->next = NULL;                   /* set end of list to NULL    */
       return;                              /* and finish                 */
   }

   temp = head;                             /* start at beginning of list */
                      /* whilst currentname < newNodename to be inserted then */
   while( strcmp( temp->id, newNode->id) < 0 ) {
          temp = temp->next;                /* goto the next node in list */
          if( temp == NULL )                /* dont go past end of list   */
              break;
   }

   /* we are the point to insert, we need previous node before we insert  */
   /* first check to see if its inserting before the first node!          */
   if( temp == head ) {
      newNode->next = head;             /* link next field to original list   */
      head = newNode;                   /* head adjusted to newNode node          */
   }
   else {     /* okay, so its not the first node, a different approach    */
      prev = head;   /* start of the list, will cycle to node before temp */
      while( prev->next != temp ) {
          prev = prev->next;
      }
      prev->next = newNode;             /* insert node between prev and next  */
      newNode->next = temp;
      if( end == prev )             /* if the newNode node is inserted at the */
         end = newNode;                 /* end of the list the adjust 'end'   */
   }
}

/* this deletes all nodes from the place specified by ptr                 */
/* if you pass it head, it will free up entire list                       */
void deletelist( struct node *ptr )
{
   struct node *temp;

   if( head == NULL ) return;   /* dont try to delete an empty list       */

   if( ptr == head ) {      /* if we are deleting the entire list         */
       head = NULL;         /* then reset head and end to signify empty   */
       end = NULL;          /* list                                       */
   }
   else {
       temp = head;          /* if its not the entire list, readjust end  */
       while( temp->next != ptr )         /* locate previous node to ptr  */
           temp = temp->next;
       end = temp;                        /* set end to node before ptr   */
   }

   while( ptr != NULL ) {   /* whilst there are still nodes to delete     */
      temp = ptr->next;     /* record address of next node                */
      free( ptr );          /* free this node                             */
      ptr = temp;           /* point to next node to be deleted           */
   }
}
