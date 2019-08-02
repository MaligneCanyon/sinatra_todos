# don't use both "completed" and "complete" for identifiers; choose one and
# stick to it to avoid annoying typos

require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

# enable sessions
configure do
  enable :sessions
  set :session_secret, 'secret'
end

# helpers should accept a Todo obj as input; sim to instance
# methods of a Todo class
helpers do
  # determine whether all todo items w/i a list are complete
  def all_complete?(list)
    list[:todos].size > 0 && list[:todos].all? { |todo| todo[:complete] }
    # todos_count(list) > 0 && todos_remaining(list) == 0 #qqq
  end

  # determine the number of todo items in a list (Todo obj)
  def todos_count(list)
    list[:todos].size
  end

  # rtn a str identifying the CSS class of a list (Todo obj)
  def list_class(list)
    "complete" if all_complete?(list)
  end

  # count the number of completed todo items w/i a list (Todo obj)
  def todos_remaining(list)
    list[:todos].count { |todo| !todo[:complete] }
  end

  # rtn a str displaying the number of remaining and total number of todo items
  def todo_counts(list)
    "#{todos_remaining(list)} / #{todos_count(list)}"
  end

  # sort some lists based on whether all list items are complete, while
  # saving the original ndx position
  def sort_lists(lists, &blk)
    # # this works but is somewhat dif to understand ...
    # indexed_lists = lists.map.with_index { |list, ndx| { list => ndx } }
    # indexed_lists.sort_by! { |indexed_list| all_complete?(indexed_list.keys[0]) ? 1 : 0 }
    # indexed_lists.each do |indexed_list|
    #   yield(indexed_list.keys[0], indexed_list.values[0])
    # end

    # # separate the lists into a groups (hashes) of incomplete and completed lists
    # # hashes are ordered for R. versions >= 1.9
    # incomplete_lists = {}
    # complete_lists = {}
    # lists.each_with_index do |list, ndx|
    #   if all_complete?(list)
    #     complete_lists[list] = ndx # hsh[key] = value
    #   else
    #     incomplete_lists[list] = ndx
    #   end
    # end
    # # rather than creating a new blk just to yield the blk args, pass the
    # # original blk (that sort_lists was called w/) to .each
    # # incomplete_lists.each { |list, ndx| yield(list, ndx) }
    # # complete_lists.each { |list, ndx| yield(list, ndx) }
    # incomplete_lists.each(&blk)
    # complete_lists.each(&blk)

    complete_lists, incomplete_lists = lists.partition { |list| all_complete?(list) }
    incomplete_lists.each { |list| yield(list, lists.index(list)) }
    complete_lists.each { |list| yield(list, lists.index(list)) }
  end

  # sort todos based on whether the todos are complete, while
  # saving the original ndx position
  def sort_todos(todos, &blk)
    # incomplete_todos = {}
    # complete_todos = {}
    # todos.each_with_index do |todo, ndx|
    #   if todo[:complete]
    #     complete_todos[todo] = ndx
    #   else
    #     incomplete_todos[todo] = ndx
    #   end
    # end
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:complete] }

    # incomplete_todos.each(&blk)
    # complete_todos.each(&blk)
    incomplete_todos.each { |todo| yield(todo, todos.index(todo)) }
    complete_todos.each { |todo| yield(todo, todos.index(todo)) }
  end
end


# make sure the user session at least contains an empty arr if there are
# no list items
before do
  session[:lists] ||= []
end

not_found do
  redirect "/lists"
end

get "/" do
  redirect "/lists"
end

# view list of lists (Todo objs)
get "/lists" do
  # @lists = [
  #   { name: "Lunch Groceries", todos: [] },
  #   { name: "Dinner Groceries", todos: [] }
  # ]
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render the new list form
get "/lists/new" do
  # add a new list (Todo obj) to the session
  # session[:lists] << { name: "New List", todos: [] }
  # redirect "/lists"

  erb :new_list, layout: :layout
end

# rtn an err msg if the name is invalid; otherwise, rtn nil
def err_for_list_name(name)
  if session[:lists].any? { |list| list[:name] == name }
    'The list name must be unique'
  elsif !(1..50).cover?(name.size)
    'The list name must have between 1 and 50 characters'
  # else
  #   nil # don't explicitly need this, but it's good to show intent
  end
end

# rtn an err msg if the todo is invalid; otherwise, rtn nil
def err_for_todo(name)
# def err_for_todo(todos, name)
  # if todos.any? { |todo| todo[:name] == name }
  #   'The todo must be unique'
  # elsif !(1..50).cover?(name.size)
  #   'The todo must have between 1 and 50 characters'
  # end
  unless (1..50).cover?(name.size)
    'The todo must have between 1 and 50 characters'
  end
end

# create a new list (Todo obj)
post "/lists" do
  list_name = params[:list_name].strip

  error = err_for_list_name(list_name)
  if error
    # display an err msg and re-render the form to allow err correction
    session[:error] = error
    erb :new_list, layout: :layout
  else
    # create the new list, display a success msg, and redirect
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created'
    redirect "/lists"
  end

  # the following code is v.dense and somewhat repetitive
  # break out error and success code to helper methods

  # if session[:lists].any? { |list| list[:name] == list_name }
  #   session[:error] = "The list name must be unique"
  #   erb :new_list, layout: :layout
  # elsif !(1..50).cover?(list_name.size)
  #   session[:error] = "The list name must have between 1 and 50 characters"
  #   erb :new_list, layout: :layout
  # else
  #   session[:lists] << { name: list_name, todos: [] }
  #   session[:success] = "The list has been created"
  #   redirect "/lists"
  # end
end

# view a specific list (Todo obj)
get "/lists/:list_ndx" do
  @list_ndx = params[:list_ndx].to_i
  @list = session[:lists][@list_ndx]
  erb :specific_list, layout: :layout
end

# edit an existing list (Todo obj)
get "/lists/:list_ndx/edit" do
  @list_ndx = params[:list_ndx].to_i
  @list = session[:lists][@list_ndx]
  erb :edit_list, layout: :layout
end

# update an existing list (Todo obj)
post "/lists/:list_ndx" do
  @list_ndx = params[:list_ndx].to_i
  @list = session[:lists][@list_ndx]
  list_name = params[:list_name].strip

  error = err_for_list_name(list_name)
  if error
    # display an err msg and re-render the form to allow err correction
    session[:error] = error
    erb :specific_list, layout: :layout
  else
    # update the list, display a success msg, and redirect
    @list[:name] = list_name
    session[:success] = 'The list name has been updated'
    # redirect "/lists/:list_ndx" # surprisingly, this doesn't work ...
    redirect "/lists/#{@list_ndx}" # ... but this does
  end
end

# delete an existing list (Todo obj) using GET
# get "/lists/:list_ndx/delete" do
# ...
# although this works, it's safer to use POST for deletion

# delete an existing list (Todo obj) using POST
post "/lists/:list_ndx/delete" do
  @list_ndx = params[:list_ndx].to_i
  @list = session[:lists][@list_ndx]

  unless session[:lists].delete_at(@list_ndx)
    # display an err msg and re-render the form to allow err correction
    session[:error] = 'Could not delete list'
    erb :edit_list, layout: :layout
  else
    # display a success msg, and redirect
    session[:success] = 'The list has been deleted'
    redirect "/lists"
  end
end

# create a todo item and add it to a list
post "/lists/:list_ndx/todos" do
  @list_ndx = params[:list_ndx].to_i
  @list = session[:lists][@list_ndx]
  text = params[:todo].strip

  # error = err_for_todo(list[:todos], text) # only req'd if todos must be unique
  error = err_for_todo(text)
  if error
    # display an err msg and re-render the form to allow err correction
    session[:error] = error
    erb :specific_list, layout: :layout
  else
    # create the new todo item, display a success msg, and redirect
    @list[:todos] << { name: text, complete: false }
    session[:success] = 'The todo was added'
    redirect "/lists/#{@list_ndx}"
  end
end

# delete a todo item from a list
post "/lists/:list_ndx/todos/:todo_ndx/delete" do
  @list_ndx = params[:list_ndx].to_i
  @list = session[:lists][@list_ndx]

  @todo_ndx = params[:todo_ndx].to_i
  @todo = @list[:todos][@todo_ndx]

  unless @list[:todos].delete_at(@todo_ndx)
    # display an err msg and re-render the form to allow err correction
    session[:error] = 'Could not delete todo'
    erb :specific_list, layout: :layout
  else
    # display a success msg, and redirect
    session[:success] = 'The todo has been deleted'
    redirect "/lists/#{@list_ndx}"
  end
end

# mark a todo item in a list as complete/incomplete
post "/lists/:list_ndx/todos/:todo_ndx" do
  @list_ndx = params[:list_ndx].to_i
  @list = session[:lists][@list_ndx]

  @todo_ndx = params[:todo_ndx].to_i
  @todo = @list[:todos][@todo_ndx]

  # get the value of the :complete flag, display a success msg, and redirect
  is_complete = params[:complete] == 'true'
  @todo[:complete] = is_complete
  session[:success] = "The todo is #{is_complete ? 'complete' : 'incomplete'}"
  redirect "/lists/#{@list_ndx}"
end

# mark all todo items in a list as complete
post "/lists/:list_ndx/complete_all" do
  @list_ndx = params[:list_ndx].to_i
  @list = session[:lists][@list_ndx]

  @list[:todos].each do |todo|
    todo[:complete] = true
  end
  session[:success] = "The todos have been completed"
  redirect "/lists/#{@list_ndx}"
end
