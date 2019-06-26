---
title: "Sync new todos"
metaTitle: "Sync new todos in public feed | GraphQL Elm Apollo Tutorial"
metaDescription: "You will learn how to sync new todos added by other people in the public feed by fetching older and newer data using GraphQL Queries"
---

Once a new todo is entered in a public list, it needs to appear in the UI. Instead of automatically displaying the todo in the UI, we use a Feed like Notification banner which appears whenever a new todo is received.

Remember that previously we have subscribed to a query which was fetching the most recent public todo added. We then fetch the initial list using the most recent public todo id.

Lets add functionality to the loadMoreSections

### Construct GraphQL Queries

Lets construct the GraphQL query for the above two operations

```
makeRequest : SelectionSet Todos RootQuery -> String -> Cmd Msg
makeRequest query authToken =
    makeGraphQLQuery
        authToken
        query
        (RemoteData.fromResult >> FetchPublicDataSuccess)

+ gtLastTodoId : Int -> OptionalArgument Integer_comparison_exp
+ gtLastTodoId id =
+     Present
+         (buildInteger_comparison_exp
+             (\args ->
+                 { args
+                     | gt_ = Present id
+                 }
+             )
+         )
+ 
+ 
+ newPublicTodosWhere : Int -> OptionalArgument Todos_bool_exp
+ newPublicTodosWhere id =
+     Present
+         (buildTodos_bool_exp
+             (\args ->
+                 { args
+                     | id = gtLastTodoId id
+                     , is_public = equalToBoolean True
+                 }
+             )
+         )
+ 
+ 
+ 
+ {-
+    Generates argument as below
+    ```
+     order_by : [
+       {
+         created_at: desc
+       }
+     ],
+      where_ : {
+        id: {
+          _gt: <id>
+        },
+        is_public: {
+          _eq: True
+        }
+      }
+    ```
+ -}
+ 
+ 
+ newPublicTodoListQueryOptionalArgs : Int -> TodosOptionalArguments -> TodosOptionalArguments
+ newPublicTodoListQueryOptionalArgs id optionalArgs =
+     { optionalArgs | where_ = newPublicTodosWhere id, order_by = orderByCreatedAt Desc }
+ 
+ 
+ newTodoQuery : Int -> SelectionSet Todos RootQuery
+ newTodoQuery id =
+     Query.todos (newPublicTodoListQueryOptionalArgs id) todoListSelectionWithUser
+ 
+ 
+ loadNewTodos : SelectionSet Todos RootQuery -> String -> Cmd Msg
+ loadNewTodos q authToken =
+     makeGraphQLQuery authToken q (RemoteData.fromResult >> FetchNewTodoDataSuccess)
+ 
+ 
+ ltLastTodoId : Int -> OptionalArgument Integer_comparison_exp
+ ltLastTodoId id =
+     Present
+         (buildInteger_comparison_exp
+             (\args ->
+                 { args
+                     | lt_ = Present id
+                 }
+             )
+         )
+ 
+ 
+ oldPublicTodosWhere : Int -> OptionalArgument Todos_bool_exp
+ oldPublicTodosWhere id =
+     Present
+         (buildTodos_bool_exp
+             (\args ->
+                 { args
+                     | id = ltLastTodoId id
+                     , is_public = equalToBoolean True
+                 }
+             )
+         )
+ 
+ 
+ oldPublicTodoListQueryOptionalArgs : Int -> TodosOptionalArguments -> TodosOptionalArguments
+ oldPublicTodoListQueryOptionalArgs id optionalArgs =
+     { optionalArgs | where_ = oldPublicTodosWhere id, order_by = orderByCreatedAt Desc, limit = OptionalArgument.Present 7 }
+ 
+ 
+ oldTodoQuery : Int -> SelectionSet Todos RootQuery
+ oldTodoQuery id =
+     Query.todos (oldPublicTodoListQueryOptionalArgs id) todoListSelectionWithUser
+ 
+ 
+ loadOldTodos : SelectionSet Todos RootQuery -> String -> Cmd Msg
+ loadOldTodos q authToken =
+     makeGraphQLQuery authToken q (RemoteData.fromResult >> FetchOldTodoDataSuccess)


```

### Add new Msg type

Lets add new `Msg` types which will be called the `loadNew` and `loadOld` buttons are clicked

```
type Msg
    = EnteredEmail String
    | EnteredPassword String
    | EnteredUsername String
    | MakeLoginRequest
    | MakeSignupRequest
    | ToggleAuthForm DisplayForm
    | GotLoginResponse LoginResponseParser
    | GotSignupResponse SignupResponseParser
    | ClearAuthToken
    | FetchPrivateDataSuccess TodoData
    | InsertPrivateTodo
    | UpdateNewTodo String
    | InsertPrivateTodoResponse (GraphQLResponse MaybeMutationResponse)
    | MarkCompleted Int Bool
    | UpdateTodo UpdateTodoItemResponse
    | DelTodo Int
    | TodoDeleted DeleteTodo
    | AllCompletedItemsDeleted AllDeleted
    | DeleteAllCompletedItems
    | Tick Time.Posix
    | UpdateLastSeen UpdateLastSeenResponse
    | GotOnlineUsers Json.Decode.Value
    | RecentPublicTodoReceived Json.Decode.Value
 		| FetchPublicDataSuccess PublicDataFetched
+   | FetchNewTodoDataSuccess PublicDataFetched
+   | FetchOldTodoDataSuccess PublicDataFetched
+   | FetchNewPublicTodos
+   | FetchOldPublicTodos
```


### Handle new Msg types in update

Lets add it to our update function to update the models appropriately


```

+       FetchNewPublicTodos ->
+           let
+               newQuery =
+                   newTodoQuery model.publicTodoInfo.currentLastTodoId
+           in
+           ( model, loadNewTodos newQuery model.authData.authToken )

+       FetchOldPublicTodos ->
+           let
+               oldQuery =
+                   oldTodoQuery model.publicTodoInfo.oldestTodoId
+           in
+           ( model, loadOldTodos oldQuery model.authData.authToken )

+       FetchOldTodoDataSuccess response ->
+           case response of
+               RemoteData.Success successData ->
+                   case List.length successData of
+                       0 ->
+                           updatePublicTodoData
+                               (\publicTodoInfo -> { publicTodoInfo | oldTodosAvailable = False })
+                               model
+                               Cmd.none

+                       _ ->
+                           let
+                               oldestTodo =
+                                   Array.get 0 (Array.fromList (List.foldl (::) [] successData))
+                           in
+                           case oldestTodo of
+                               Just item ->
+                                   updatePublicTodoData (\publicTodoInfo -> { publicTodoInfo | todos = List.append publicTodoInfo.todos successData, oldestTodoId = item.id }) model Cmd.none

+                               Nothing ->
+                                   ( model, Cmd.none )

+               _ ->
+                   ( model, Cmd.none )

+       FetchNewTodoDataSuccess response ->
+           case response of
+               RemoteData.Success successData ->
+                   case List.length successData of
+                       0 ->
+                           ( model, Cmd.none )

+                       _ ->
+                           let
+                               newestTodo =
+                                   Array.get 0 (Array.fromList successData)
+                           in
+                           case newestTodo of
+                               Just item ->
+                                   updatePublicTodoData (\publicTodoInfo -> { publicTodoInfo | todos = List.append successData publicTodoInfo.todos, currentLastTodoId = item.id, newTodoCount = 0 }) model Cmd.none

+                               Nothing ->
+                                   ( model, Cmd.none )

+               _ ->
+                   ( model, Cmd.none )



```


Let's populate initial state by fetching the existing list of todos in `componentDidMount()`

```javascript
class _TodoPublicList extends Component {
  constructor(props) {
    ...
  }

  loadNew() {
  }

  loadOlder() {
  }

+  componentDidMount() {
+    this.loadOlder();
+  }

   render() {
     ...
   }
}
```

Update the `loadOlder` method to the following:

```javascript
  loadOlder() {
+    const GET_OLD_PUBLIC_TODOS = gql`
+      query getOldPublicTodos ($oldestTodoId: Int!) {
+        todos (where: { is_public: { _eq: true}, id: {_lt: $oldestTodoId}}, limit: 7, order_by: { created_at: desc }) {
+          id
+          title
+          created_at
+          user {
+            name
+          }
+        }
+      }`;
+
+    this.client.query({
+      query: GET_OLD_PUBLIC_TODOS,
+      variables: {oldestTodoId: (this.oldestTodoId)}
+    })
+    .then(({data}) => {
+      if (data.todos.length) {
+        this.oldestTodoId = data.todos[data.todos.length - 1].id;
+        this.setState({todos: [...this.state.todos, ...data.todos]});
+      } else {
+        this.setState({olderTodosAvailable: false});
+      }
+    })
+    .catch(error => {
+      console.error(error);
+      this.setState({error: true});
+    });
  }
```

We are defining a query to fetch older public todos and making a `client.query` call to get the data from the database. Once we get the data, we update the `todos` state to re-render the UI with the available list of public todos.

Try adding a new todo in the public feed and notice that it will not show up on the UI. Now refresh the page to see the added todo.

This happens because we haven't yet implemented a way to show the newly added todo to the feed.

Let's handle that in `componentDidUpdate()` lifecycle method

```javascript
+ componentDidUpdate(prevProps) {
+  // Do we have a new todo available?
+  if (this.props.latestTodo.id > this.newestTodoId) {
+    this.newestTodoId = this.props.latestTodo.id;
+    this.setState({newTodosCount: this.state.newTodosCount + 1});
+  }
+ }

  componentDidMount() {
    ...
  }
```

Now try adding a new todo to the public feed and you will see the notification appearing saying that a new task has arrived.

Great! We still have one functionality left. When a new task arrives on the public feed and when the user clicks on the New tasks section, we should make a query to re-fetch the todos that are not present on our current public feed.

Update `loadNew()` method with the following code

```javascript
  loadNew() {
+   const GET_NEW_PUBLIC_TODOS = gql`
+     query getNewPublicTodos ($latestVisibleId: Int!) {
+       todos(where: { is_public: { _eq: true}, id: {_gt: $latestVisibleId}}, order_by: { created_at: desc }) {
+         id
+         title
+         created_at
+         user {
+           name
+         }
+       }
+     }
+   `;
+
+   this.client.query({
+     query: GET_NEW_PUBLIC_TODOS,
+     variables: {latestVisibleId: this.state.todos[0].id}
+   })
+   .then(({data}) => {
+     this.newestTodoId = data.todos[0].id;
+     this.setState({todos: [...data.todos, ...this.state.todos], newTodosCount: 0});
+   })
+   .catch(error => {
+     console.error(error);
+     this.setState({error: true});
+   });
  }
```
