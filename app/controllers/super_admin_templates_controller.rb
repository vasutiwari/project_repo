class SuperAdminTemplatesController < ApplicationController
  # GET /super_admin_templates
  # GET /super_admin_templates.xml
  def index
    @super_admin_templates = SuperAdminTemplate.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @super_admin_templates }
    end
  end

  # GET /super_admin_templates/1
  # GET /super_admin_templates/1.xml
  def show
    @super_admin_template = SuperAdminTemplate.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @super_admin_template }
    end
  end

  # GET /super_admin_templates/new
  # GET /super_admin_templates/new.xml
  def new
    @super_admin_template = SuperAdminTemplate.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @super_admin_template }
    end
  end

  # GET /super_admin_templates/1/edit
  def edit
    @super_admin_template = SuperAdminTemplate.find(params[:id])
  end

  # POST /super_admin_templates
  # POST /super_admin_templates.xml
  def create
    @super_admin_template = SuperAdminTemplate.new(params[:super_admin_template])

    respond_to do |format|
      if @super_admin_template.save
        format.html { redirect_to(@super_admin_template, :notice => 'Super admin template was successfully created.') }
        format.xml  { render :xml => @super_admin_template, :status => :created, :location => @super_admin_template }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @super_admin_template.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /super_admin_templates/1
  # PUT /super_admin_templates/1.xml
  def update
    @super_admin_template = SuperAdminTemplate.find(params[:id])

    respond_to do |format|
      if @super_admin_template.update_attributes(params[:super_admin_template])
        format.html { redirect_to(@super_admin_template, :notice => 'Super admin template was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @super_admin_template.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /super_admin_templates/1
  # DELETE /super_admin_templates/1.xml
  def destroy
    @super_admin_template = SuperAdminTemplate.find(params[:id])
    @super_admin_template.destroy

    respond_to do |format|
      format.html { redirect_to(super_admin_templates_url) }
      format.xml  { head :ok }
    end
  end
end
